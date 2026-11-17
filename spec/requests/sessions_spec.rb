require "rails_helper"

RSpec.describe "Sessions" do
  let(:user) { create(:user) }

  describe "GET /session/new" do
    it "renders the sign-in form with Google" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("form[action='/session']")).to be_present
      expect(response.parsed_body.css("form[action='/auth/google'] button").text).to eq("Sign in with Google")
    end

    it "sends a signed-in user to the dashboard" do
      sign_in_as(user)
      get new_session_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /session" do
    it "signs in with valid credentials, resets failures and audits" do
      user.update_columns(failed_login_attempts: 3)

      expect { sign_in_with_password(user) }.to change(user.sessions, :count).by(1)

      expect(response).to redirect_to(root_url)
      expect(cookies["session_id"]).to be_present
      expect(user.reload.failed_login_attempts).to eq(0)
      event = AuditEvent.where(action: "login.succeeded", user_id: user.id).sole
      expect(event.metadata).to eq("via" => "password", "mfa" => false)
    end

    it "accepts the email in any case" do
      post session_path, params: { email_address: user.email_address.upcase, password: AuthenticationHelpers::PASSWORD }
      expect(response).to redirect_to(root_url)
    end

    it "refuses a wrong password with a generic message and counts the attempt" do
      expect { sign_in_with_password(user, password: "wrong-password") }.not_to change(Session, :count)

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq(SessionsController::GENERIC_FAILURE)
      expect(cookies["session_id"]).to be_blank
      expect(user.reload.failed_login_attempts).to eq(1)
      expect(AuditEvent.where(action: "login.failed", user_id: user.id)).to exist
    end

    it "gives the same answer for an unknown email, without revealing it" do
      post session_path, params: { email_address: "nobody@example.com", password: "whatever-password" }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq(SessionsController::GENERIC_FAILURE)
      event = AuditEvent.where(action: "login.failed").sole
      expect(event.user).to be_nil
      expect(event.metadata["attempted_email"]).to eq("nobody@example.com")
    end

    it "copes with missing params and truncates a huge attempted email" do
      post session_path
      expect(response).to redirect_to(new_session_path)

      post session_path, params: { email_address: "x" * 1000, password: "p" }
      expect(AuditEvent.where(action: "login.failed").last.metadata["attempted_email"].length).to eq(254)
    end

    it "locks the account after too many failures" do
      user.update_columns(failed_login_attempts: User::MAX_FAILED_LOGINS - 1)

      expect { sign_in_with_password(user, password: "wrong-password") }.to have_enqueued_mail(UserMailer, :account_locked)
      expect(user.reload).to be_locked
    end

    it "refuses a locked account even with the right password" do
      locked = create(:user, :locked)

      sign_in_with_password(locked)

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq(SessionsController::GENERIC_FAILURE)
      expect(locked.sessions).to be_empty
      expect(AuditEvent.find_by!(action: "login.blocked", user_id: locked.id).metadata).to eq("reason" => "locked")
    end

    it "sends unverified users to confirm their email" do
      unverified = create(:user, :unverified)
      sign_in_with_password(unverified)

      expect(response).to redirect_to(new_email_verification_path)
      expect(unverified.sessions).to be_empty
    end

    it "asks for a second factor instead of signing in when 2FA is on" do
      enable_two_factor(user)

      expect { sign_in_with_password(user) }.not_to change(Session, :count)

      expect(response).to redirect_to(new_two_factor_challenge_path)
      expect(session[:pending_mfa]).to include("user_id" => user.id, "via" => "password")
      expect(cookies["session_id"]).to be_blank
    end

    it "does not let an invited (unaccepted) user sign in" do
      invited = create(:user, :invited)
      post session_path, params: { email_address: invited.email_address, password: "a-long-secret-123" }
      expect(response).to redirect_to(new_session_path)
    end

    it "rate-limits repeated attempts from one IP" do
      10.times { |i| post session_path, params: { email_address: "guess#{i}@example.com", password: "x" } }

      post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try again later.")
      expect(user.sessions).to be_empty
    end
  end

  describe "DELETE /session" do
    it "signs out, clears the cookie and audits" do
      current = sign_in_as(user)

      delete session_path

      expect(response).to redirect_to(new_session_path)
      expect(response).to have_http_status(:see_other)
      expect(Session.exists?(current.id)).to be(false)
      expect(cookies["session_id"]).to be_blank
      expect(AuditEvent.where(action: "logout", user_id: user.id)).to exist

      get root_path
      expect(response).to redirect_to(new_session_path)
    end

    it "requires being signed in" do
      delete session_path
      expect(response).to redirect_to(new_session_path)
      expect(AuditEvent.where(action: "logout")).to be_empty
    end
  end
end
