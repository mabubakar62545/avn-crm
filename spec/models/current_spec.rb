require "rails_helper"

RSpec.describe Current do
  it "exposes the session's user" do
    session = create(:session)
    described_class.session = session
    expect(described_class.user).to eq(session.user)
  end

  it "has no user without a session" do
    expect(described_class.user).to be_nil
  end
end
