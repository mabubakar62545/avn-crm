class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  encrypts :otp_secret
  has_many :recovery_codes, dependent: :delete_all
  has_many :identities, dependent: :destroy
  belongs_to :invited_by, class_name: "User", optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address,
            presence: true,
            uniqueness: true,
            length: { maximum: 254 },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password, length: { minimum: 12 }, allow_nil: true
  validate  :password_must_differ_from_email, if: -> { password.present? }

  MAX_FAILED_LOGINS = 10
  LOCKOUT_DURATION  = 30.minutes

  OTP_ISSUER = "AVN CRM"
  RECOVERY_CODE_COUNT = 10

  # client: signs up themselves (password or Google).
  # manager (employee) and admin: only created from the console or by an admin invitation.
  ROLES = %w[client manager admin].freeze   # ordered lowest → highest
  INVITATION_TTL = 7.days

  enum :role, ROLES.index_by(&:itself), default: "client", validate: true

  after_update_commit :revoke_other_sessions, if: :saved_change_to_password_digest?
  before_save :clear_lockout, if: :will_save_change_to_password_digest?
  before_save :stamp_password_set_at, if: :will_save_change_to_password_digest?
  after_create_commit  :audit_registration, unless: :invited_at?
  after_update_commit  :audit_security_changes

  generates_token_for :email_verification, expires_in: 2.days do
    email_address
  end

  # Resending bumps invited_at and accepting sets verified_at, so either kills older links.
  generates_token_for :invitation, expires_in: INVITATION_TTL do
    [ invited_at&.to_i, verified_at&.to_i, password_set_at&.to_i ]
  end

  # Company email domains (config.x.staff_domains). Addresses on these domains
  # can't self-register: staff accounts come from an invitation.
  def self.staff_email?(email)
    domain = email.to_s.strip.downcase.split("@").last
    domain.present? && Array(Rails.configuration.x.staff_domains).include?(domain)
  end

  # Creates an account and emails the person a link to finish setting it up.
  # Console: User.invite!(email_address: "jane@yourcompany.com", role: "manager")
  def self.invite!(email_address:, role:, invited_by: nil)
    user = new(email_address:, role:, invited_by:, invited_at: Time.current)
    user.assign_unusable_password
    user.save!
    UserMailer.invitation(user).deliver_later
    AuditEvent.record("user.invited", user:, actor: invited_by, role: user.role, via: invited_by ? "admin" : "console")
    user
  end

  def invitation_pending? = invited_at.present? && !verified?
  def invitation_expired? = invitation_pending? && invited_at < INVITATION_TTL.ago

  def resend_invitation!
    update!(invited_at: Time.current)
    UserMailer.invitation(self).deliver_later
  end

  def accept_invitation(password:, password_confirmation:)
    if password.blank?
      errors.add(:password, :blank)
      return false
    end
    update(password:, password_confirmation:, verified_at: Time.current)
  end

  # Gives SSO-provisioned accounts an unusable password the user never sees.
  # The account stays "password not set" until they choose one via reset.
  def assign_unusable_password
    @unusable_password = true
    self.password = SecureRandom.base58(32)
  end

  def password_set? = password_set_at.present?

  # The user must keep at least one way to sign in.
  def can_unlink_identity? = password_set? || identities.count > 1

  def verified? = verified_at.present?
  def verify!   = update!(verified_at: Time.current)
  def locked? = locked_until&.future?
  def at_least?(role_name) = ROLES.index(role) >= ROLES.index(role_name.to_s)

  def register_failed_login!
    return if locked?

    self.class.where(id: id).update_all("failed_login_attempts = failed_login_attempts + 1")
    reload
    lock_account! if failed_login_attempts >= MAX_FAILED_LOGINS
  end

  def reset_failed_logins!
    update_columns(failed_login_attempts: 0) if failed_login_attempts.positive?
  end

  def otp_enabled? = otp_enabled_at.present?

  def otp_provisioning_uri(secret)
    ROTP::TOTP.new(secret, issuer: OTP_ISSUER).provisioning_uri(email_address)
  end

  # Returns true once per valid code; rejects reuse of the same code.
  def verify_otp(code, secret: otp_secret)
    return false if secret.blank? || code.blank?

    timestamp = ROTP::TOTP.new(secret).verify(
      code.to_s.gsub(/\s/, ""),
      drift_behind: 30, drift_ahead: 30,
      after: otp_last_used_at
    )
    timestamp.present? && update_columns(otp_last_used_at: timestamp)
  end

  def enable_otp!(secret)
    transaction do
      update!(otp_secret: secret, otp_enabled_at: Time.current)
      regenerate_recovery_codes!
    end
  end

  # Returns the plaintext codes. This is the ONLY time they exist unhashed.
  def regenerate_recovery_codes!
    recovery_codes.delete_all
    Array.new(RECOVERY_CODE_COUNT) { SecureRandom.alphanumeric(10).downcase.insert(5, "-") }.tap do |codes|
      codes.each { |c| recovery_codes.create!(code_digest: RecoveryCode.digest(c)) }
    end
  end

  def consume_recovery_code(code)
    return false if code.blank?

    recovery_codes.unused
                  .where(code_digest: RecoveryCode.digest(code))
                  .update_all(used_at: Time.current) == 1
  end

  def disable_otp!
    transaction do
      update!(otp_secret: nil, otp_enabled_at: nil, otp_last_used_at: nil)
      recovery_codes.delete_all
    end
  end

  private
    def password_must_differ_from_email
      errors.add(:password, "can't contain your email") if
        password.downcase.include?(email_address.to_s.split("@").first.to_s)
    end

    def revoke_other_sessions
      sessions.where.not(id: Current.session&.id).delete_all
    end

    def lock_account!
      update_columns(locked_until: LOCKOUT_DURATION.from_now, failed_login_attempts: 0)
      AuditEvent.record("account.locked", user: self)
      UserMailer.account_locked(self).deliver_later
    end

    def stamp_password_set_at
      self.password_set_at = @unusable_password ? nil : Time.current
      @unusable_password = false
    end

    def clear_lockout
      self.locked_until = nil
      self.failed_login_attempts = 0
    end

    def audit_registration = AuditEvent.record("user.registered", user: self)

    def audit_security_changes
      AuditEvent.record("password.changed", user: self) if saved_change_to_password_digest?
      AuditEvent.record("email.verified",   user: self) if saved_change_to_verified_at? && verified?
      AuditEvent.record("role.changed", user: self, from: role_before_last_save, to: role) if saved_change_to_role?

      if saved_change_to_otp_enabled_at?
        AuditEvent.record(otp_enabled? ? "mfa.enabled" : "mfa.disabled", user: self)
      end
    end
end
