require "rails_helper"

RSpec.describe PasswordsMailer do
  let(:user) { create(:user) }

  subject(:mail) { described_class.reset(user) }

  it "sends a working reset link to the user" do
    expect(mail.to).to eq([ user.email_address ])
    expect(mail.subject).to eq("Reset your password")

    token = mail.text_part.body.to_s[%r{/passwords/(\S+)/edit}, 1]
    expect(User.find_by_password_reset_token(token)).to eq(user)
    expect(mail.text_part.body.to_s).to include("15 minutes")
  end
end
