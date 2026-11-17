require "rails_helper"

RSpec.describe SessionPolicy do
  subject { described_class }

  let(:user) { create(:user) }
  let!(:current) { create(:session, user:) }
  let!(:other_device) { create(:session, user:) }
  let!(:someone_elses) { create(:session) }

  before { Current.session = current }

  permissions :destroy? do
    it { is_expected.to permit(user, other_device) }
    it { is_expected.not_to permit(user, current) }
    it { is_expected.not_to permit(user, someone_elses) }
  end

  permissions :others? do
    it { is_expected.to permit(user, Session) }
  end

  describe SessionPolicy::Scope do
    it "returns only the user's own sessions" do
      expect(described_class.new(user, Session).resolve).to contain_exactly(current, other_device)
    end
  end
end
