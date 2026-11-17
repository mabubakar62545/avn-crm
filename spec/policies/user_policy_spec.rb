require "rails_helper"

RSpec.describe UserPolicy do
  subject { described_class }

  let(:admin)   { create(:user, :admin) }
  let(:manager) { create(:user, :manager) }
  let(:client)  { create(:user, :client) }
  let(:other)   { create(:user) }
  let(:invited) { create(:user, :invited) }

  permissions :index?, :show? do
    it { is_expected.to permit(admin, other) }
    it { is_expected.to permit(manager, other) }
    it { is_expected.not_to permit(client, other) }
    it { is_expected.not_to permit(client, client) }
  end

  permissions :update? do
    it { is_expected.to permit(admin, other) }
    it { is_expected.not_to permit(admin, admin) }
    it { is_expected.not_to permit(manager, other) }
    it { is_expected.not_to permit(manager, manager) }
    it { is_expected.not_to permit(client, client) }
  end

  permissions :unlock?, :revoke_sessions?, :invite? do
    it { is_expected.to permit(admin, other) }
    it { is_expected.not_to permit(manager, other) }
    it { is_expected.not_to permit(client, other) }
  end

  permissions :resend_invitation? do
    it { is_expected.to permit(admin, invited) }
    it { is_expected.not_to permit(admin, other) }
    it { is_expected.not_to permit(manager, invited) }
    it { is_expected.not_to permit(client, invited) }
  end

  describe "#permitted_attributes" do
    it "lets an admin change only another user's role" do
      expect(described_class.new(admin, other).permitted_attributes).to eq(%i[role])
    end

    it "permits nothing for an admin's own record, managers, or clients" do
      expect(described_class.new(admin, admin).permitted_attributes).to eq([])
      expect(described_class.new(manager, other).permitted_attributes).to eq([])
      expect(described_class.new(client, client).permitted_attributes).to eq([])
    end
  end

  describe UserPolicy::Scope do
    before { [ admin, manager, client, other ] }

    it "shows managers and admins everyone" do
      expect(described_class.new(admin, User).resolve).to match_array(User.all)
      expect(described_class.new(manager, User).resolve).to match_array(User.all)
    end

    it "shows clients only themselves" do
      expect(described_class.new(client, User).resolve).to contain_exactly(client)
    end
  end
end
