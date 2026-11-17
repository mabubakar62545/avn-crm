module AuthenticationHelpers
  PASSWORD = "TestPassword123!"

  # Signs in by planting a signed session cookie, the same way the app does.
  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
    Current.session
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end

  # Signs in through the real form.
  def sign_in_with_password(user, password: PASSWORD)
    post session_path, params: { email_address: user.email_address, password: }
  end

  # Turns on 2FA for a user and returns [secret, recovery_codes].
  def enable_two_factor(user)
    secret = ROTP::Base32.random
    [ secret, user.enable_otp!(secret) ]
  end

  def current_otp(secret) = ROTP::TOTP.new(secret).now

  def flash_text = response.parsed_body.css(".flash").text
end

module OmniAuthHelpers
  def mock_google(uid: "google-uid-1", email: "someone@gmail.com", verified: true, **extra)
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      { provider: "google", uid:, info: { email:, email_verified: verified } }.merge(extra)
    )
  end

  def return_from_google(**)
    mock_google(**)
    post "/auth/google"
    follow_redirect!
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include OmniAuthHelpers, type: :request

  config.around(:each, type: :request) do |example|
    OmniAuth.config.test_mode = true
    example.run
  ensure
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.test_mode = false
  end

  # Controller-level rate_limit sits behind Rack::Attack, which throttles some of the same
  # paths more tightly. Tag an example `rack_attack: false` to reach the controller's limit.
  config.around(:each, rack_attack: false) do |example|
    Rack::Attack.enabled = false
    example.run
  ensure
    Rack::Attack.enabled = true
  end
end
