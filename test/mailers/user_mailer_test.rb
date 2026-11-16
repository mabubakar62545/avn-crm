require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup { @user = users(:unverified) }

  test "email_verification" do
    mail = UserMailer.email_verification(@user)
    assert_equal "Confirm your email address", mail.subject
    assert_equal [ @user.email_address ], mail.to
    assert_match "/email_verifications/", mail.text_part.body.to_s
    assert_match "/email_verifications/", mail.html_part.body.to_s
  end

  test "already_registered" do
    mail = UserMailer.already_registered(@user)
    assert_equal "Someone tried to sign up with your email", mail.subject
    assert_equal [ @user.email_address ], mail.to
  end

  test "text parts are plain text" do
    %i[ email_verification already_registered account_locked recovery_code_used two_factor_disabled ].each do |name|
      mail = UserMailer.public_send(name, @user)
      assert_no_match(/<p>|<a /, mail.text_part.body.to_s, "#{name}.text.erb contains HTML")
    end
  end
end
