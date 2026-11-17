require "rails_helper"

RSpec.describe RecoveryCode do
  it { is_expected.to belong_to(:user) }

  describe ".normalize" do
    it "lowercases and drops anything that isn't a letter or digit" do
      expect(described_class.normalize(" AbCdE-12345 ")).to eq("abcde12345")
      expect(described_class.normalize(nil)).to eq("")
    end
  end

  describe ".digest" do
    it "is a deterministic HMAC of the normalized code" do
      expect(described_class.digest("abcde-12345")).to eq(described_class.digest("ABCDE12345"))
      expect(described_class.digest("abcde-12345")).to match(/\A\h{64}\z/)
      expect(described_class.digest("abcde-12345")).not_to eq(described_class.digest("abcde-12346"))
    end
  end

  describe ".unused" do
    it "excludes used codes" do
      user = create(:user)
      unused = user.recovery_codes.create!(code_digest: "a")
      user.recovery_codes.create!(code_digest: "b", used_at: Time.current)
      expect(described_class.unused).to contain_exactly(unused)
    end
  end
end
