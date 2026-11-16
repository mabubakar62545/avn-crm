require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "requires a 12+ character password that doesn't contain the email name" do
    assert_not User.new(email_address: "a@example.com", password: "short").valid?
    assert_not User.new(email_address: "jane@example.com", password: "jane-is-very-long").valid?
    assert User.new(email_address: "jane@example.com", password: "a-long-secret-123").valid?
  end

  test "role ranking" do
    assert users(:admin).at_least?(:manager)
    assert users(:manager).at_least?(:manager)
    assert_not users(:member).at_least?(:manager)
  end

  test "locks after too many failed logins" do
    user = users(:member)
    User::MAX_FAILED_LOGINS.times { user.register_failed_login! }
    assert user.locked?
  end

  test "an authenticator code can only be used once" do
    user = users(:member)
    secret = ROTP::Base32.random
    user.enable_otp!(secret)
    code = ROTP::TOTP.new(secret).now

    assert user.verify_otp(code)
    assert_not user.verify_otp(code)
  end

  test "recovery codes are single use and stored hashed" do
    user = users(:member)
    codes = user.enable_otp!(ROTP::Base32.random)

    assert_equal User::RECOVERY_CODE_COUNT, codes.size
    assert_not user.recovery_codes.exists?(code_digest: codes.first)
    assert user.consume_recovery_code(codes.first.upcase)
    assert_not user.consume_recovery_code(codes.first)
  end

  test "the otp secret is encrypted at rest" do
    user = users(:member)
    secret = ROTP::Base32.random
    user.enable_otp!(secret)

    raw = User.connection.select_value("SELECT otp_secret FROM users WHERE id = #{user.id}")
    assert_not_equal secret, raw
    assert_equal secret, user.reload.otp_secret
  end
end
