require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:client) }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path

    follow_redirect!
    assert_flash "reset instructions sent"
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_session_path

    follow_redirect!
    assert_flash "reset instructions sent"
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_flash "reset link is invalid"
  end

  test "update changes the password, unlocks, and signs out everywhere" do
    @user.sessions.create!
    @user.update_columns(locked_until: 1.hour.from_now)

    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "brand-new-secret-1", password_confirmation: "brand-new-secret-1" }
      assert_redirected_to new_session_path
    end

    assert_not @user.reload.locked?
    assert_empty @user.sessions

    follow_redirect!
    assert_flash "Password has been reset"
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "brand-new-secret-1", password_confirmation: "something-else-1" }
      assert_redirected_to edit_password_path(token)
    end

    follow_redirect!
    assert_flash "Password confirmation doesn't match"
  end

  test "update with a too-short password" do
    token = @user.password_reset_token
    put password_path(token), params: { password: "short", password_confirmation: "short" }

    follow_redirect!
    assert_flash "too short"
  end
end
