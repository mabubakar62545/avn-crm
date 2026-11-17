require "rails_helper"

RSpec.describe SsoSignIn do
  def auth(email: "newbie@gmail.com", uid: "uid-1", verified: true, extra: nil)
    OmniAuth::AuthHash.new(provider: :google, uid:, info: { email:, email_verified: verified }, extra:)
  end

  def call(...) = described_class.new(auth(...)).call

  describe "a returning user with a linked identity" do
    let!(:identity) { create(:identity, uid: "uid-1", email: "old@gmail.com", last_used_at: nil) }

    it "signs them in and refreshes the identity" do
      result = call(email: " NEW@Gmail.com ", verified: false)

      expect(result.user).to eq(identity.user)
      expect(result).to have_attributes(error: nil, created: false, accepted_invitation: false)
      expect(identity.reload.email).to eq("new@gmail.com")
      expect(identity.last_used_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "email verification from the provider" do
    it "accepts email_verified as true or \"true\" on info" do
      expect(call(email: "a@gmail.com", uid: "a", verified: true).user).to be_present
      expect(call(email: "b@gmail.com", uid: "b", verified: "true").user).to be_present
    end

    it "accepts email_verified from the raw id-token claims" do
      result = call(verified: nil, extra: { raw_info: { "email_verified" => "true" } })
      expect(result.user).to be_present
    end

    it "refuses an unverified email" do
      [ false, "false", nil ].each do |value|
        result = call(verified: value)
        expect(result.user).to be_nil
        expect(result.error).to match(/isn't verified/)
      end
    end

    it "refuses when extra is present but carries no raw info" do
      expect(call(verified: nil, extra: { other: 1 }).user).to be_nil
    end
  end

  describe "a new person" do
    it "provisions a verified client with no usable password and links the identity" do
      result = nil
      expect { result = call(email: "  Newbie@Gmail.com ") }.to change(User, :count).by(1)

      user = result.user
      expect(result.created).to be(true)
      expect(user).to have_attributes(email_address: "newbie@gmail.com", role: "client")
      expect(user).to be_verified
      expect(user).not_to be_password_set
      expect(user.identities.pluck(:provider, :uid, :email)).to eq([ [ "google", "uid-1", "newbie@gmail.com" ] ])
    end

    it "refuses staff-domain addresses (staff join by invitation)" do
      result = nil
      expect { result = call(email: "jane@avn.example") }.not_to change(User, :count)
      expect(result.error).to eq(described_class::STAFF_BY_INVITATION)
    end
  end

  describe "an existing account with that email" do
    it "refuses to take over a password account" do
      create(:user, email_address: "taken@gmail.com")
      result = call(email: "taken@gmail.com")
      expect(result.user).to be_nil
      expect(result.error).to match(/already exists/)
    end

    context "with a pending invitation" do
      let!(:invited) { create(:user, :invited, :manager, email_address: "jane@avn.example") }

      it "accepts the invitation, verifying the account and linking the identity" do
        result = call(email: "jane@avn.example", uid: "jane-uid")

        expect(result.user).to eq(invited)
        expect(result.accepted_invitation).to be(true)
        expect(invited.reload).to be_verified
        expect(invited.role).to eq("manager")
        expect(invited.identities.pluck(:uid)).to eq([ "jane-uid" ])
        expect(AuditEvent.find_by!(action: "invitation.accepted", user_id: invited.id).metadata).to eq("via" => "google")
      end

      it "refuses an expired invitation" do
        invited.update_columns(invited_at: 8.days.ago)
        result = call(email: "jane@avn.example")
        expect(result.error).to match(/expired/)
        expect(invited.reload).not_to be_verified
        expect(invited.identities).to be_empty
      end
    end
  end
end
