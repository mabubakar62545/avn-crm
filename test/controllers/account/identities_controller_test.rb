require "test_helper"

class Account::IdentitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:client)
    sign_in_as @user
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.test_mode = false
  end

  def return_from_google(uid: "google-uid-1", email: "client@example.com")
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(provider: "google", uid:, info: { email: })
    post "/auth/google"
    follow_redirect!
  end

  test "security page shows the Google sign-in method" do
    get account_sessions_path
    assert_response :success
    assert_select "#sign_in_methods", /Google/
  end

  test "signed-in user returning from Google links the account" do
    assert_difference -> { @user.identities.count }, 1 do
      return_from_google
    end
    assert_redirected_to account_sessions_path(anchor: "sign_in_methods")
    assert_equal "google-uid-1", @user.identities.sole.uid
  end

  test "linking a Google account owned by another user is refused" do
    users(:admin).identities.create!(provider: "google", uid: "google-uid-1")

    assert_no_difference -> { Identity.count } do
      return_from_google
    end
    assert_match(/different user/, flash[:alert])
  end

  test "linking a second Google account is refused" do
    @user.identities.create!(provider: "google", uid: "other-uid")

    assert_no_difference -> { Identity.count } do
      return_from_google
    end
    assert_match(/Unlink it first/, flash[:alert])
  end

  test "linked user can sign in with Google next time" do
    return_from_google
    sign_out

    assert_difference -> { @user.sessions.count }, 1 do
      return_from_google
    end
    assert_redirected_to root_url
  end

  test "destroy unlinks only the current user's identity" do
    identity = @user.identities.create!(provider: "google", uid: "google-uid-1")
    other    = users(:admin).identities.create!(provider: "google", uid: "admin-uid")

    delete account_identity_path(other)
    assert_response :not_found
    assert Identity.exists?(other.id)

    delete account_identity_path(identity)
    assert_redirected_to account_sessions_path(anchor: "sign_in_methods")
    assert_not Identity.exists?(identity.id)
  end

  test "a Google-only user cannot unlink their only sign-in method" do
    sign_out
    user = users(:sso_only)
    identity = user.identities.create!(provider: "google", uid: "sso-uid")
    sign_in_as user

    get account_sessions_path
    assert_select "#unlink_blocked"
    assert_select "#password_not_set"

    assert_no_difference -> { Identity.count } do
      delete account_identity_path(identity)
    end
    assert_redirected_to account_sessions_path(anchor: "sign_in_methods")
    assert_match(/Set a password/, flash[:alert])
  end

  test "a Google-only user can unlink once they have set a password" do
    sign_out
    user = users(:sso_only)
    identity = user.identities.create!(provider: "google", uid: "sso-uid")
    user.update!(password: "a-brand-new-passphrase")
    assert user.password_set?
    sign_in_as user

    delete account_identity_path(identity)
    assert_not Identity.exists?(identity.id)
  end

  test "Google sign-in still asks for the 2FA code when it is on" do
    secret, _codes = enable_two_factor(@user)
    return_from_google
    sign_out

    assert_no_difference -> { @user.sessions.count } do
      return_from_google
    end
    assert_redirected_to new_two_factor_challenge_path

    assert_difference -> { @user.sessions.count }, 1 do
      post two_factor_challenge_path, params: { code: current_otp(secret) }
    end
    assert_redirected_to root_url
    assert_equal "sso:google", AuditEvent.where(action: "login.succeeded").last.metadata["via"]
  end
end
