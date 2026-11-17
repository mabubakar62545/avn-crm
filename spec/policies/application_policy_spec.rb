require "rails_helper"

RSpec.describe ApplicationPolicy do
  subject(:policy) { described_class.new(user, record) }

  let(:user) { build(:user, :admin) }
  let(:record) { Object.new }

  it "exposes the user and record" do
    expect(policy).to have_attributes(user:, record:)
  end

  it "denies everything by default, even to admins" do
    %i[index? show? create? new? update? edit? destroy?].each do |action|
      expect(policy.public_send(action)).to be(false), "expected #{action} to be denied"
    end
  end

  it "derives new? from create? and edit? from update?" do
    permissive = Class.new(described_class) do
      def create? = true
      def update? = true
    end.new(user, record)

    expect(permissive.new?).to be(true)
    expect(permissive.edit?).to be(true)
  end

  describe ApplicationPolicy::Scope do
    it "forces subclasses to define #resolve" do
      expect { described_class.new(user, User).resolve }.to raise_error(NoMethodError, /You must define #resolve/)
    end
  end
end
