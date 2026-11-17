require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = User.invite!(email_address: "jane@avn.example", role: "manager", invited_by: users(:admin))
    @token = @user.generate_token_for(:invitation)
  end

  def accept(password: "a-long-secret-123", confirmation: password, token: @token)
    patch invitation_path(token), params: { password:, password_confirmation: confirmation }
  end

  test "the invited user can't sign in before accepting" do
    assert @user.invitation_pending?
    assert_not @user.password_set?
    assert_nil User.authenticate_by(email_address: @user.email_address, password: "")
  end

  test "show offers a password form and Google" do
    get invitation_path(@token)
    assert_response :success
    assert_select "form#accept_invitation_form"
    assert_select "form[action='/auth/google'] button", "Accept with Google"
  end

  test "accepting with a password verifies the account and signs in" do
    accept
    assert_redirected_to root_url

    @user.reload
    assert @user.verified?
    assert @user.password_set?
    assert_equal "manager", @user.role
    assert_equal 1, @user.sessions.count
    assert AuditEvent.exists?(action: "invitation.accepted", user_id: @user.id)
  end

  test "the link stops working once accepted" do
    accept
    sign_out
    get invitation_path(@token)
    assert_redirected_to new_session_path
  end

  test "resending invalidates the old link" do
    travel 1.second
    @user.resend_invitation!
    get invitation_path(@token)
    assert_redirected_to new_session_path
  end

  test "the link expires after a week" do
    travel 8.days
    get invitation_path(@token)
    assert_redirected_to new_session_path
  end

  test "mismatched or blank passwords re-render the form" do
    accept(confirmation: "something-else-123")
    assert_response :unprocessable_entity
    assert_not @user.reload.verified?

    accept(password: "", confirmation: "")
    assert_response :unprocessable_entity
    assert_not @user.reload.verified?
  end
end
