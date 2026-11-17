require "rails_helper"

RSpec.describe AuditEvent do
  it { is_expected.to belong_to(:actor).class_name("User").optional }
  it { is_expected.to belong_to(:user).optional }
  it { is_expected.to validate_presence_of(:action) }

  it "orders .recent newest first" do
    older = create(:audit_event, created_at: 1.day.ago)
    newer = create(:audit_event)
    expect(described_class.recent.where(id: [ older.id, newer.id ])).to eq([ newer, older ])
  end

  it "is append-only once saved" do
    event = create(:audit_event)
    expect(event).to be_readonly
    expect { event.update!(action: "tampered") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "is writable before it is saved" do
    expect(described_class.new).not_to be_readonly
  end

  describe ".record" do
    let(:user)  { create(:user) }
    let(:actor) { create(:user, :admin) }

    before do
      Current.ip_address = "203.0.113.7"
      Current.user_agent = "A" * 300
      Current.request_id = "req-123"
    end

    it "stores the event with request details and metadata" do
      event = described_class.record("thing.happened", user:, actor:, reason: "test")

      expect(event).to be_persisted
      expect(event).to have_attributes(
        action: "thing.happened", user:, actor:, user_email: user.email_address,
        ip_address: "203.0.113.7", request_id: "req-123", metadata: { "reason" => "test" }
      )
      expect(event.user_agent.length).to eq(255)
    end

    it "defaults the actor to the signed-in user" do
      Current.session = create(:session, user: actor)
      expect(described_class.record("thing.happened", user:).actor).to eq(actor)
    end

    it "works with no user, actor or user agent" do
      Current.user_agent = nil
      event = described_class.record("anonymous.thing")
      expect(event).to have_attributes(user: nil, actor: nil, user_email: nil, user_agent: nil)
    end

    it "writes a structured log line" do
      allow(Rails.logger).to receive(:info).and_call_original
      described_class.record("thing.happened", user:, actor:)
      expect(Rails.logger).to have_received(:info).with(a_string_including('"audit":"thing.happened"', %("user_id":#{user.id}), %("actor_id":#{actor.id})))
    end

    it "never breaks the caller: errors are reported and nil is returned" do
      allow(Rails.error).to receive(:report)
      expect(described_class.record(nil)).to be_nil
      expect(Rails.error).to have_received(:report).with(an_instance_of(ActiveRecord::RecordInvalid), context: { audit_action: nil })
    end
  end
end
