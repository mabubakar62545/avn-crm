require "test_helper"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:unverified) }

  test "new" do
    get new_email_verification_path
    assert_response :success
  end

  test "create resends the link to unverified users" do
    post email_verifications_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with UserMailer, :email_verification, args: [ @user ]
    assert_redirected_to new_session_path
  end

  test "create sends nothing to already verified users" do
    post email_verifications_path, params: { email_address: users(:member).email_address }
    assert_enqueued_emails 0
  end

  test "show asks for confirmation instead of verifying on GET" do
    get email_verification_path(@user.generate_token_for(:email_verification))

    assert_response :success
    assert_not @user.reload.verified?
  end

  test "update verifies the email" do
    patch email_verification_path(@user.generate_token_for(:email_verification))

    assert_redirected_to new_session_path
    assert @user.reload.verified?
    assert AuditEvent.exists?(action: "email.verified", user_id: @user.id)
  end

  test "an invalid token is rejected" do
    get email_verification_path("nope")
    assert_redirected_to new_email_verification_path
  end
end
