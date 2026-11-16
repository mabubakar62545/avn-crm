require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:member) }

  test "new renders the sign-in form" do
    get new_session_path
    assert_response :success
    assert_select "form#sign_in_form"
  end

  test "new redirects when already signed in" do
    sign_in_as @user
    get new_session_path
    assert_redirected_to root_path
  end

  test "create with valid credentials signs in and audits" do
    assert_difference -> { AuditEvent.where(action: "login.succeeded").count } do
      post session_path, params: { email_address: @user.email_address, password: PASSWORD }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create returns to the page that required sign-in" do
    get account_sessions_path
    post session_path, params: { email_address: @user.email_address, password: PASSWORD }
    assert_redirected_to account_sessions_url
  end

  test "create with invalid credentials fails and counts the attempt" do
    assert_difference -> { @user.reload.failed_login_attempts } do
      post session_path, params: { email_address: @user.email_address, password: "wrong" }
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert AuditEvent.exists?(action: "login.failed", user_id: @user.id)
  end

  test "create locks the account after too many failures" do
    @user.update_columns(failed_login_attempts: User::MAX_FAILED_LOGINS - 1)

    assert_enqueued_email_with UserMailer, :account_locked, args: [ @user ] do
      post session_path, params: { email_address: @user.email_address, password: "wrong" }
    end
    assert @user.reload.locked?
  end

  test "create refuses a locked account even with the right password" do
    post session_path, params: { email_address: users(:locked).email_address, password: PASSWORD }
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "create sends unverified users to confirm their email" do
    post session_path, params: { email_address: users(:unverified).email_address, password: PASSWORD }
    assert_redirected_to new_email_verification_path
  end

  test "create asks for a code when two-factor is on" do
    enable_two_factor(@user)
    post session_path, params: { email_address: @user.email_address, password: PASSWORD }

    assert_redirected_to new_two_factor_challenge_path
    assert_nil cookies[:session_id]
  end

  test "destroy signs out and audits" do
    sign_in_as @user

    assert_difference -> { AuditEvent.where(action: "logout").count } do
      delete session_path
    end

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
