require "rails_helper"

RSpec.describe Session do
  it { is_expected.to belong_to(:user) }

  it "records last activity on create" do
    expect(create(:session).last_active_at).to be_within(1.second).of(Time.current)
  end

  describe "#expired?" do
    let(:session) { create(:session) }

    it "is false for a fresh session" do
      expect(session).not_to be_expired
    end

    it "is true after the idle timeout" do
      session.update_columns(last_active_at: (described_class::IDLE_TIMEOUT + 1.minute).ago)
      expect(session).to be_expired
    end

    it "is true after the absolute timeout even if recently active" do
      session.update_columns(created_at: (described_class::ABSOLUTE_TIMEOUT + 1.minute).ago, last_active_at: Time.current)
      expect(session).to be_expired
    end
  end

  describe ".expired" do
    it "returns idle and too-old sessions only" do
      fresh = create(:session)
      idle  = create(:session, last_active_at: 3.hours.ago)
      old   = create(:session, created_at: 3.weeks.ago)

      expect(described_class.expired).to contain_exactly(idle, old)
      expect(described_class.expired).not_to include(fresh)
    end
  end

  describe "#record_activity!" do
    let(:session) { create(:session) }

    it "does not write within the throttle window" do
      expect { session.record_activity! }.not_to change { session.reload.last_active_at }
    end

    it "bumps last_active_at once the throttle window has passed" do
      travel described_class::ACTIVITY_THROTTLE + 1.second
      session.record_activity!
      expect(session.reload.last_active_at).to be_within(1.second).of(Time.current)
    end
  end
end
