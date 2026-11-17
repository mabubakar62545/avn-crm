require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
    assert_select "form#registration_form"
  end

  test "create makes an unverified user and emails a confirmation link" do
    assert_difference -> { User.count } do
      post registration_path, params: { user: { email_address: "new@example.com", password: "a-long-secret-123", password_confirmation: "a-long-secret-123" } }
    end

    user = User.find_by!(email_address: "new@example.com")
    assert_not user.verified?
    assert_equal "client", user.role
    assert_enqueued_email_with UserMailer, :email_verification, args: [ user ]
    assert_redirected_to new_session_path
  end

  test "create with an existing email does not reveal it and notifies the owner" do
    existing = users(:client)

    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { email_address: existing.email_address, password: "a-long-secret-123", password_confirmation: "a-long-secret-123" } }
    end

    assert_enqueued_email_with UserMailer, :already_registered, args: [ existing ]
    assert_redirected_to new_session_path
  end

  test "create with invalid data re-renders the form with errors" do
    post registration_path, params: { user: { email_address: "bad@example.com", password: "short", password_confirmation: "other" } }

    assert_response :unprocessable_entity
    assert_select "#form_errors li", minimum: 1
  end

  test "a staff-domain email cannot self-register" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { email_address: "jane@avn.example", password: "a-long-secret-123", password_confirmation: "a-long-secret-123" } }
    end
    assert_response :unprocessable_entity
    assert_select "#form_errors li", /created by invitation/
  end

  test "a role sent in the form is ignored" do
    post registration_path, params: { user: { email_address: "sneaky@example.com", password: "a-long-secret-123", password_confirmation: "a-long-secret-123", role: "admin" } }
    assert_equal "client", User.find_by!(email_address: "sneaky@example.com").role
  end
end
