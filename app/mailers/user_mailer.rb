# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def email_verification(user)
    @token = user.generate_token_for(:email_verification)
    mail to: user.email_address, subject: "Confirm your email address"
  end

  def already_registered(user)
    mail to: user.email_address, subject: "Someone tried to sign up with your email"
  end

  def account_locked(user)
    mail to: user.email_address, subject: "Your account was temporarily locked"
  end
end


