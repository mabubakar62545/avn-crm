class UserMailer < ApplicationMailer
  def email_verification(user)
    @token = user.generate_token_for(:email_verification)
    mail to: user.email_address, subject: "Confirm your email address"
  end

  def invitation(user)
    @user  = user
    @token = user.generate_token_for(:invitation)
    mail to: user.email_address, subject: "You've been invited to AVN CRM"
  end

  def already_registered(user)
    mail to: user.email_address, subject: "Someone tried to sign up with your email"
  end

  def account_locked(user)
    mail to: user.email_address, subject: "Your account was temporarily locked"
  end

  def recovery_code_used(user)
    @remaining = user.recovery_codes.unused.count
    mail to: user.email_address, subject: "A recovery code was used to sign in"
  end

  def two_factor_disabled(user)
    mail to: user.email_address, subject: "Two-factor authentication was turned off"
  end
end
