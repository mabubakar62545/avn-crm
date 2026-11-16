module SessionTestHelper
  PASSWORD = "TestPassword123!"

  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end

  # Turns on 2FA for a user and returns [secret, recovery_codes].
  def enable_two_factor(user)
    secret = ROTP::Base32.random
    codes = user.enable_otp!(secret)
    [ secret, codes ]
  end

  def current_otp(secret) = ROTP::TOTP.new(secret).now

  def assert_flash(text)
    assert_select ".flash", /#{Regexp.escape(text)}/i
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
