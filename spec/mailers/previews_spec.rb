require "rails_helper"

RSpec.describe "Mailer previews" do
  it "loads from spec/mailers/previews and renders every email" do
    create(:user)
    previews = ActionMailer::Preview.all.map(&:name)
    expect(previews).to include("UserMailerPreview", "PasswordsMailerPreview")

    ActionMailer::Preview.all.each do |preview|
      preview.emails.each do |email|
        expect(preview.call(email).to).to be_present, "#{preview.name}##{email} did not render"
      end
    end
  end
end
