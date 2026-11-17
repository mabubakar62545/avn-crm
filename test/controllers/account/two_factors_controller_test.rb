require "test_helper"

class Account::TwoFactorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:client)
    sign_in_as @user
  end

  test "new shows a QR code and secret" do
    get new_account_two_factor_path
    assert_response :success
    assert_select ".qr svg"
    assert_select "#otp_secret"
  end

  test "create with a valid code enables 2FA and shows recovery codes once" do
    get new_account_two_factor_path
    secret = session[:pending_otp_secret]

    post account_two_factor_path, params: { code: current_otp(secret) }

    assert_response :success
    assert_select "#recovery_codes li", User::RECOVERY_CODE_COUNT
    assert @user.reload.otp_enabled?
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "create with a wrong code does not enable 2FA" do
    get new_account_two_factor_path
    post account_two_factor_path, params: { code: "000000" }

    assert_redirected_to new_account_two_factor_path
    assert_not @user.reload.otp_enabled?
  end

  test "new redirects when 2FA is already on" do
    enable_two_factor(@user)
    get new_account_two_factor_path
    assert_redirected_to account_sessions_path
  end

  test "destroy needs the password and a code" do
    secret, = enable_two_factor(@user)

    delete account_two_factor_path, params: { password: "wrong", code: current_otp(secret) }
    assert @user.reload.otp_enabled?

    delete account_two_factor_path, params: { password: PASSWORD, code: current_otp(secret) }
    assert_not @user.reload.otp_enabled?
    assert_enqueued_email_with UserMailer, :two_factor_disabled, args: [ @user ]
  end

  test "a Google-only user turns off 2FA with just a code" do
    sign_out
    user = users(:sso_only)
    sign_in_as user
    secret, = enable_two_factor(user)

    get account_sessions_path
    assert_select "#disable_two_factor_form input[name=password]", 0

    delete account_two_factor_path, params: { code: "000000" }
    assert user.reload.otp_enabled?

    delete account_two_factor_path, params: { code: current_otp(secret) }
    assert_not user.reload.otp_enabled?
  end
end
