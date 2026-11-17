require "test_helper"

class SsoSignUpTest < ActionDispatch::IntegrationTest
  setup { OmniAuth.config.test_mode = true }

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.test_mode = false
  end

  def continue_with_google(email:, uid: "new-uid", verified: true)
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid:, info: { email:, email_verified: verified }
    )
    post "/auth/google"
    follow_redirect!
  end

  test "sign-up page offers Google" do
    get new_registration_path
    assert_select "form[action='/auth/google'] button", "Sign up with Google"
  end

  test "a new Google user gets a verified account and is signed in" do
    assert_difference -> { User.count }, 1 do
      continue_with_google(email: "newbie@gmail.com")
    end
    assert_redirected_to root_url
    assert_equal "Welcome! Your account has been created.", flash[:notice]

    user = User.find_by!(email_address: "newbie@gmail.com")
    assert user.verified?
    assert_not user.password_set?, "the generated password must not count as one the user chose"
    assert_equal [ [ "google", "new-uid" ] ], user.identities.pluck(:provider, :uid)
    assert_equal 1, user.sessions.count
  end

  test "an unverified Google email cannot sign up" do
    assert_no_difference -> { User.count } do
      continue_with_google(email: "newbie@gmail.com", verified: false)
    end
    assert_redirected_to new_session_path
  end

  test "Google sign-up from any domain creates a client" do
    continue_with_google(email: "buyer@some-client.example")
    assert_equal "client", User.find_by!(email_address: "buyer@some-client.example").role
  end

  test "a staff-domain email cannot self sign-up" do
    assert_no_difference -> { User.count } do
      continue_with_google(email: "jane@avn.example")
    end
    assert_redirected_to new_session_path
    assert_equal SsoSignIn::STAFF_BY_INVITATION, flash[:alert]
  end

  test "an invited employee accepts the invitation with Google" do
    invited = User.invite!(email_address: "jane@avn.example", role: "manager")

    assert_no_difference -> { User.count } do
      continue_with_google(email: "jane@avn.example", uid: "jane-uid")
    end
    assert_redirected_to root_url
    assert_match(/invitation has been accepted/, flash[:notice])

    invited.reload
    assert invited.verified?
    assert_equal "manager", invited.role
    assert_not invited.invitation_pending?
    assert_equal [ [ "google", "jane-uid" ] ], invited.identities.pluck(:provider, :uid)
    assert AuditEvent.exists?(action: "invitation.accepted", user_id: invited.id)
  end

  test "an expired invitation cannot be accepted with Google" do
    invited = User.invite!(email_address: "jane@avn.example", role: "manager")
    invited.update_columns(invited_at: 8.days.ago)

    continue_with_google(email: "jane@avn.example")
    assert_redirected_to new_session_path
    assert_match(/expired/, flash[:alert])
    assert_not invited.reload.verified?
    assert_empty invited.identities
  end

  test "an email that already has a password account is told to link instead" do
    User.create!(email_address: "taken@gmail.com", password: "a-long-secret-123", verified_at: Time.current)

    assert_no_difference -> { User.count } do
      continue_with_google(email: "taken@gmail.com")
    end
    assert_match(/link single sign-on/, flash[:alert])
  end
end
