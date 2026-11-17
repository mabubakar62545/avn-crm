require "rails_helper"

RSpec.describe UserMailer do
  let(:user) { create(:user, :unverified) }

  def links(mail) = [ mail.text_part.body.to_s, mail.html_part.body.to_s ]

  shared_examples "a security email" do |subject_line|
    it "goes to the user from the app address with the right subject" do
      expect(mail.to).to eq([ user.email_address ])
      expect(mail.from).to eq([ "no-reply@avn-crm.local" ])
      expect(mail.subject).to eq(subject_line)
    end

    it "has a plain-text part without HTML" do
      expect(mail.text_part.body.to_s).not_to match(/<p>|<a /)
      expect(mail.html_part).to be_present
    end
  end

  describe "#email_verification" do
    subject(:mail) { described_class.email_verification(user) }

    it_behaves_like "a security email", "Confirm your email address"

    it "links to a token that verifies this user" do
      token = mail.text_part.body.to_s[%r{/email_verifications/([^\s"]+)}, 1]
      expect(User.find_by_token_for(:email_verification, token)).to eq(user)
      expect(links(mail)).to all(include("/email_verifications/"))
    end
  end

  describe "#invitation" do
    let(:admin) { create(:user, :admin) }
    let(:user) { User.invite!(email_address: "jane@avn.example", role: "manager", invited_by: admin) }

    subject(:mail) { described_class.invitation(user) }

    it_behaves_like "a security email", "You've been invited to AVN CRM"

    it "names the inviter and role and links to a working invitation" do
      body = mail.text_part.body.to_s
      expect(body).to include("#{admin.email_address} has invited you", "as Manager")
      token = body[%r{/invitations/(\S+)}, 1]
      expect(User.find_by_token_for(:invitation, token)).to eq(user)
    end

    it "reads naturally for console invitations" do
      console = User.invite!(email_address: "ops@avn.example", role: "admin")
      expect(described_class.invitation(console).text_part.body.to_s).to include("You've been invited")
    end
  end

  describe "#already_registered" do
    subject(:mail) { described_class.already_registered(user) }

    it_behaves_like "a security email", "Someone tried to sign up with your email"
  end

  describe "#account_locked" do
    subject(:mail) { described_class.account_locked(user) }

    it_behaves_like "a security email", "Your account was temporarily locked"

    it("states the lockout length") { expect(mail.text_part.body.to_s).to include("30 minutes") }
  end

  describe "#recovery_code_used" do
    subject(:mail) { described_class.recovery_code_used(user) }

    before do
      codes = user.enable_otp!(ROTP::Base32.random)
      user.consume_recovery_code(codes.first)
    end

    it_behaves_like "a security email", "A recovery code was used to sign in"

    it("says how many codes remain") { expect(mail.text_part.body.to_s).to include("You have 9 left") }
  end

  describe "#two_factor_disabled" do
    subject(:mail) { described_class.two_factor_disabled(user) }

    it_behaves_like "a security email", "Two-factor authentication was turned off"
  end
end
