# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/email_verification
  def email_verification
    UserMailer.email_verification
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/already_registered
  def already_registered
    UserMailer.already_registered
  end
end
