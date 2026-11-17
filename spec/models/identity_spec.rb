require "rails_helper"

RSpec.describe Identity do
  it { is_expected.to belong_to(:user) }

  it "is unique per provider account and per user/provider" do
    identity = create(:identity, uid: "abc")
    expect { create(:identity, uid: "abc") }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { create(:identity, user: identity.user, uid: "other") }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
