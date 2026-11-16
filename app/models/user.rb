# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

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

  after_update_commit :revoke_other_sessions, if: :saved_change_to_password_digest?
  before_save :clear_lockout, if: :will_save_change_to_password_digest?

  generates_token_for :email_verification, expires_in: 2.days do
    email_address
  end

  def verified? = verified_at.present?
  def verify!   = update!(verified_at: Time.current)
  def locked? = locked_until&.future?

  def register_failed_login!
    return if locked?

    self.class.where(id: id).update_all("failed_login_attempts = failed_login_attempts + 1")
    reload
    lock_account! if failed_login_attempts >= MAX_FAILED_LOGINS
  end

  def reset_failed_logins!
    update_columns(failed_login_attempts: 0) if failed_login_attempts.positive?
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
      UserMailer.account_locked(self).deliver_later
    end

    def clear_lockout
      self.locked_until = nil
      self.failed_login_attempts = 0
    end
end