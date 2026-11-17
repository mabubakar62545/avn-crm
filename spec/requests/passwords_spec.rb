require "rails_helper"

RSpec.describe "Password reset" do
  let(:user) { create(:user) }

  it "GET /passwords/new renders the form" do
    get new_password_path
    expect(response).to have_http_status(:ok)
  end

  describe "POST /passwords" do
    it "emails reset instructions and audits the request" do
      expect { post passwords_path, params: { email_address: user.email_address } }
        .to have_enqueued_mail(PasswordsMailer, :reset).with(user)

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(flash_text).to match(/reset instructions sent/i)
      expect(AuditEvent.where(action: "password.reset_requested", user_id: user.id)).to exist
    end

    it "gives the same answer for an unknown email but sends nothing" do
      expect { post passwords_path, params: { email_address: "missing@example.com" } }.not_to have_enqueued_mail

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(flash_text).to match(/reset instructions sent/i)
    end

    it "is rate-limited", rack_attack: false do
      10.times { post passwords_path, params: { email_address: "x#{_1}@example.com" } }

      expect { post passwords_path, params: { email_address: user.email_address } }.not_to have_enqueued_mail
      expect(response).to redirect_to(new_password_path)
      expect(flash[:alert]).to eq("Try again later.")
    end
  end

  describe "GET /passwords/:token/edit" do
    it "renders the form for a valid token" do
      get edit_password_path(user.password_reset_token)
      expect(response).to have_http_status(:ok)
    end

    it "rejects an invalid token" do
      get edit_password_path("invalid token")
      expect(response).to redirect_to(new_password_path)
      follow_redirect!
      expect(flash_text).to match(/reset link is invalid/i)
    end

    it "rejects an expired token" do
      token = user.password_reset_token
      travel 16.minutes
      get edit_password_path(token)
      expect(response).to redirect_to(new_password_path)
    end
  end

  describe "PUT /passwords/:token" do
    def reset(token, password: "brand-new-secret-1", confirmation: password)
      put password_path(token), params: { password:, password_confirmation: confirmation }
    end

    it "changes the password, unlocks the account and signs out everywhere" do
      user.sessions.create!
      user.update_columns(locked_until: 1.hour.from_now)

      expect { reset(user.password_reset_token) }.to change { user.reload.password_digest }

      expect(response).to redirect_to(new_session_path)
      expect(user).not_to be_locked
      expect(user.sessions).to be_empty
      expect(user.authenticate("brand-new-secret-1")).to eq(user)
      follow_redirect!
      expect(flash_text).to match(/Password has been reset/)
    end

    it "lets an SSO-only user set their first password" do
      sso = create(:user, :sso_only)
      reset(sso.password_reset_token)
      expect(sso.reload).to be_password_set
    end

    it "works only once per token" do
      token = user.password_reset_token
      reset(token)
      expect { reset(token, password: "yet-another-secret-2") }.not_to change { user.reload.password_digest }
      expect(response).to redirect_to(new_password_path)
    end

    it "rejects mismatched passwords" do
      token = user.password_reset_token
      expect { reset(token, confirmation: "something-else-1") }.not_to change { user.reload.password_digest }

      expect(response).to redirect_to(edit_password_path(token))
      follow_redirect!
      expect(flash_text).to match(/Password confirmation doesn't match/)
    end

    it "rejects a too-short password" do
      reset(user.password_reset_token, password: "short")
      follow_redirect!
      expect(flash_text).to match(/too short/)
    end

    it "rejects an invalid token" do
      reset("bogus")
      expect(response).to redirect_to(new_password_path)
    end
  end
end
