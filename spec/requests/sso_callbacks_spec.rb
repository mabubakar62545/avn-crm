require "rails_helper"

RSpec.describe "Single sign-on (Google)" do
  describe "signing in or up" do
    it "creates a verified client for a new Google user and signs them in" do
      expect { return_from_google(email: "newbie@gmail.com", uid: "new-uid") }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to eq("Welcome! Your account has been created.")
      user = User.find_by!(email_address: "newbie@gmail.com")
      expect(user.sessions.count).to eq(1)
      expect(AuditEvent.where(action: "login.succeeded", user_id: user.id).sole.metadata["via"]).to eq("sso:google")
    end

    it "signs a returning linked user in without a welcome message" do
      identity = create(:identity, uid: "known")

      return_from_google(uid: "known", email: identity.user.email_address)

      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to be_nil
      expect(identity.user.sessions.count).to eq(1)
    end

    it "accepts a pending invitation" do
      invited = create(:user, :invited, :manager, email_address: "jane@avn.example")

      expect { return_from_google(email: "jane@avn.example", uid: "jane-uid") }.not_to change(User, :count)

      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to match(/invitation has been accepted/)
      expect(invited.reload).to be_verified
    end

    it "refuses an unverified Google email and audits the failure" do
      expect { return_from_google(email: "newbie@gmail.com", verified: false) }.not_to change(User, :count)

      expect(response).to redirect_to(new_session_path)
      event = AuditEvent.where(action: "sso.failed").sole
      expect(event.metadata).to include("provider" => "google", "attempted_email" => "newbie@gmail.com")
    end

    it "refuses a staff-domain self sign-up" do
      return_from_google(email: "jane@avn.example")
      expect(flash[:alert]).to eq(SsoSignIn::STAFF_BY_INVITATION)
    end

    it "refuses an expired invitation" do
      create(:user, :invited, email_address: "jane@avn.example", invited_at: 8.days.ago)
      return_from_google(email: "jane@avn.example")
      expect(flash[:alert]).to match(/expired/)
    end

    it "tells an existing password user to link from settings instead" do
      create(:user, email_address: "taken@gmail.com")
      expect { return_from_google(email: "taken@gmail.com") }.not_to change(Session, :count)
      expect(flash[:alert]).to match(/link single sign-on/)
    end

    it "refuses a locked account with the generic message" do
      locked = create(:user, :locked)
      create(:identity, user: locked, uid: "locked-uid")

      return_from_google(uid: "locked-uid", email: locked.email_address)

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq(SessionsController::GENERIC_FAILURE)
      expect(locked.sessions).to be_empty
      expect(AuditEvent.find_by!(action: "login.blocked", user_id: locked.id).metadata).to include("via" => "sso")
    end

    it "still asks for the second factor when 2FA is on" do
      user = create(:user)
      enable_two_factor(user)
      create(:identity, user:, uid: "mfa-uid")

      expect { return_from_google(uid: "mfa-uid", email: user.email_address) }.not_to change(Session, :count)
      expect(response).to redirect_to(new_two_factor_challenge_path)
      expect(session[:pending_mfa]).to include("via" => "sso:google")
    end

    it "only starts SSO from a POST (CSRF-safe request phase)" do
      get "/auth/google"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "provider failures" do
    before { OmniAuth.config.mock_auth[:google] = :invalid_credentials }

    it "sends an anonymous visitor back to sign in and audits" do
      post "/auth/google"
      2.times { follow_redirect! } # request phase -> callback -> /auth/failure
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Single sign-on failed. Please try again.")
      expect(AuditEvent.where(action: "sso.failed").sole.metadata["reason"]).to eq("invalid_credentials")
    end

    it "sends a signed-in user back to their security page" do
      sign_in_as(create(:user))
      post "/auth/google"
      2.times { follow_redirect! }
      expect(response).to redirect_to(account_sessions_path)
    end

    it "truncates an oversized failure reason" do
      get "/auth/failure", params: { message: "x" * 500 }
      expect(AuditEvent.where(action: "sso.failed").sole.metadata["reason"].length).to eq(100)
    end
  end

  describe "linking while signed in" do
    let(:user) { create(:user) }
    let(:methods_path) { account_sessions_path(anchor: "sign_in_methods") }

    before { sign_in_as(user) }

    it "links the Google account and audits" do
      expect { return_from_google(uid: "g-1", email: " Me@Gmail.com ") }.to change(user.identities, :count).by(1)

      expect(response).to redirect_to(methods_path)
      expect(flash[:notice]).to eq("Google account linked. You can now use it to sign in.")
      expect(user.identities.sole).to have_attributes(provider: "google", uid: "g-1", email: "me@gmail.com")
      expect(AuditEvent.where(action: "sso.linked", user_id: user.id)).to exist
    end

    it "is a no-op when that Google account is already linked to me" do
      create(:identity, user:, uid: "g-1")
      expect { return_from_google(uid: "g-1") }.not_to change(Identity, :count)
      expect(flash[:notice]).to eq("That Google account is already linked.")
    end

    it "refuses a Google account linked to someone else (no account takeover)" do
      victim = create(:identity, uid: "g-1")

      expect { return_from_google(uid: "g-1") }.not_to change(Identity, :count)

      expect(flash[:alert]).to match(/different user/)
      expect(victim.reload.user).not_to eq(user)
      expect(AuditEvent.find_by!(action: "sso.link_failed", user_id: user.id).metadata["reason"]).to eq("linked_to_another_user")
    end

    it "refuses a second Google account" do
      create(:identity, user:, uid: "first")
      expect { return_from_google(uid: "second") }.not_to change(Identity, :count)
      expect(flash[:alert]).to match(/Unlink it first/)
    end

    it "lets the linked account sign in next time" do
      return_from_google(uid: "g-1")
      sign_out

      expect { return_from_google(uid: "g-1") }.to change(user.sessions, :count).by(1)
      expect(response).to redirect_to(root_url)
    end
  end
end
