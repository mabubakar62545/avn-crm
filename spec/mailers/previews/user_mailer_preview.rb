# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def email_verification = UserMailer.email_verification(user)
  def already_registered = UserMailer.already_registered(user)
  def account_locked     = UserMailer.account_locked(user)
  def recovery_code_used = UserMailer.recovery_code_used(user)
  def two_factor_disabled = UserMailer.two_factor_disabled(user)

  private
    def user = User.first || User.new(email_address: "preview@example.com")
end
