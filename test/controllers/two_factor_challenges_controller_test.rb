require "test_helper"

class TwoFactorChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:client)
    @secret, @codes = enable_two_factor(@user)
  end

  test "without a pending sign-in it sends you back to sign in" do
    get new_two_factor_challenge_path
    assert_redirected_to new_session_path
  end

  test "a valid authenticator code completes sign-in" do
    start_sign_in
    get new_two_factor_challenge_path
    assert_response :success

    post two_factor_challenge_path, params: { code: current_otp(@secret) }
    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "a recovery code completes sign-in once and emails the user" do
    start_sign_in
    post two_factor_challenge_path, params: { code: @codes.first }

    assert_redirected_to root_path
    assert_enqueued_email_with UserMailer, :recovery_code_used, args: [ @user ]
    assert_equal User::RECOVERY_CODE_COUNT - 1, @user.recovery_codes.unused.count
  end

  test "a wrong code is rejected" do
    start_sign_in
    post two_factor_challenge_path, params: { code: "000000" }

    assert_redirected_to new_two_factor_challenge_path
    assert_nil cookies[:session_id]
    assert AuditEvent.exists?(action: "mfa.failed", user_id: @user.id)
  end

  private
    def start_sign_in
      post session_path, params: { email_address: @user.email_address, password: PASSWORD }
      assert_redirected_to new_two_factor_challenge_path
    end
end
