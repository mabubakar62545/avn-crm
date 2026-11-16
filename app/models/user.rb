# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  encrypts :otp_secret
  has_many :recovery_codes, dependent: :delete_all

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

  ROLES = %w[member manager admin].freeze   # ordered lowest → highest

  enum :role, ROLES.index_by(&:itself), default: "member", validate: true



  after_update_commit :revoke_other_sessions, if: :saved_change_to_password_digest?
  before_save :clear_lockout, if: :will_save_change_to_password_digest?
  after_create_commit  :audit_registration
  after_update_commit  :audit_security_changes


  generates_token_for :email_verification, expires_in: 2.days do
    email_address
  end

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