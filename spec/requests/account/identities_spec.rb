require "rails_helper"

RSpec.describe "Account: linked sign-in methods" do
  let(:user) { create(:user) }
  let(:methods_path) { account_sessions_path(anchor: "sign_in_methods") }

  it "requires sign-in" do
    identity = create(:identity, user:)
    delete account_identity_path(identity)
    expect(response).to redirect_to(new_session_path)
    expect(Identity.exists?(identity.id)).to be(true)
  end

  context "when signed in with a password account" do
    before { sign_in_as(user) }

    it "shows the Google sign-in method" do
      get account_sessions_path
      expect(response.parsed_body.css("#sign_in_methods").text).to include("Google", "Not linked")
    end

    it "unlinks my identity (audited)" do
      identity = create(:identity, user:)

      delete account_identity_path(identity)

      expect(response).to redirect_to(methods_path)
      expect(flash[:notice]).to eq("Google account unlinked.")
      expect(Identity.exists?(identity.id)).to be(false)
      expect(AuditEvent.find_by!(action: "sso.unlinked", user_id: user.id).metadata).to eq("provider" => "google")
    end

    it "cannot unlink another user's identity" do
      other = create(:identity)
      delete account_identity_path(other)
      expect(response).to have_http_status(:not_found)
      expect(Identity.exists?(other.id)).to be(true)
    end
  end

  context "when the user only signs in with Google" do
    let(:user) { create(:user, :sso_only) }
    let!(:identity) { create(:identity, user:) }

    before { sign_in_as(user) }

    it "cannot remove their only way to sign in" do
      get account_sessions_path
      expect(response.parsed_body.css("#unlink_blocked")).to be_present
      expect(response.parsed_body.css("#password_not_set")).to be_present

      expect { delete account_identity_path(identity) }.not_to change(Identity, :count)
      expect(response).to redirect_to(methods_path)
      expect(flash[:alert]).to match(/Set a password/)
    end

    it "can unlink once they have set a password" do
      user.update!(password: "a-brand-new-passphrase")
      delete account_identity_path(identity)
      expect(Identity.exists?(identity.id)).to be(false)
    end
  end
end
