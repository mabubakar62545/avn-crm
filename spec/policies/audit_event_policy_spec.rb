require "rails_helper"

RSpec.describe AuditEventPolicy do
  subject { described_class }

  let(:admin)   { create(:user, :admin) }
  let(:manager) { create(:user, :manager) }
  let(:client)  { create(:user, :client) }

  permissions :index? do
    it { is_expected.to permit(admin, AuditEvent) }
    it { is_expected.not_to permit(manager, AuditEvent) }
    it { is_expected.not_to permit(client, AuditEvent) }
  end

  permissions :show?, :create?, :update?, :destroy? do
    it { is_expected.not_to permit(admin, AuditEvent) }
  end

  describe AuditEventPolicy::Scope do
    before { create(:audit_event) }

    it "shows admins every event" do
      expect(described_class.new(admin, AuditEvent).resolve).to match_array(AuditEvent.all)
    end

    it "shows everyone else nothing" do
      expect(described_class.new(manager, AuditEvent).resolve).to be_empty
      expect(described_class.new(client, AuditEvent).resolve).to be_empty
    end
  end
end
