require "rails_helper"

RSpec.describe ApplicationHelper do
  describe "#sso_provider_enabled?" do
    it "is true for configured providers only" do
      expect(helper.sso_provider_enabled?(:google)).to be(true)
      expect(helper.sso_provider_enabled?("google")).to be(true)
      expect(helper.sso_provider_enabled?(:github)).to be(false)
    end
  end

  describe "#nav_link_to" do
    it "marks the link for the current page" do
      allow(helper).to receive(:current_page?).with("/").and_return(true)
      html = Nokogiri::HTML.fragment(helper.nav_link_to("Dashboard", "/")).at("a")
      expect(html["class"]).to eq("nav__link is-active")
      expect(html["aria-current"]).to eq("page")
    end

    it "leaves other links plain" do
      allow(helper).to receive(:current_page?).with("/").and_return(false)
      html = Nokogiri::HTML.fragment(helper.nav_link_to("Dashboard", "/")).at("a")
      expect(html["class"]).to eq("nav__link")
      expect(html["aria-current"]).to be_nil
    end

    it "with prefix: true, matches any page beneath the path" do
      allow(helper.request).to receive(:path).and_return("/admin/users/3")
      expect(helper.nav_link_to("Users", "/admin/users", prefix: true)).to include("is-active")
      expect(helper.nav_link_to("Audit", "/admin/audit_events", prefix: true)).not_to include("is-active")
    end
  end

  describe "#badge" do
    it "renders a toned badge, neutral by default" do
      expect(helper.badge("Hi")).to eq('<span class="badge badge--neutral">Hi</span>')
      expect(helper.badge("Hi", :danger)).to eq('<span class="badge badge--danger">Hi</span>')
    end

    it "escapes the text" do
      expect(helper.badge("<script>")).to include("&lt;script&gt;")
    end
  end

  describe "#role_badge" do
    it "colours each role" do
      expect(helper.role_badge(build(:user, :admin))).to eq('<span class="badge badge--danger">Admin</span>')
      expect(helper.role_badge(build(:user, :manager))).to eq('<span class="badge badge--info">Manager</span>')
      expect(helper.role_badge(build(:user, :client))).to eq('<span class="badge badge--neutral">Client</span>')
    end
  end

  describe "#status_badge" do
    it "shows locked, expired invite, invited, or active" do
      expect(helper.status_badge(build(:user, locked_until: 1.hour.from_now))).to include("Locked", "badge--danger")
      expect(helper.status_badge(build(:user, :invited, invited_at: 8.days.ago))).to include("Invite expired", "badge--danger")
      expect(helper.status_badge(build(:user, :invited))).to include("Invited", "badge--warning")
      expect(helper.status_badge(build(:user))).to include("Active", "badge--success")
    end
  end

  describe "#yes_no_badge" do
    it "renders yes/no with optional labels" do
      expect(helper.yes_no_badge(true)).to include("Yes", "badge--success")
      expect(helper.yes_no_badge(false)).to include("No", "badge--warning")
      expect(helper.yes_no_badge(true, yes: "On", no: "Off")).to include("On")
      expect(helper.yes_no_badge(nil, yes: "On", no: "Off")).to include("Off")
    end
  end

  describe "#device_label" do
    {
      nil => "Unknown device",
      "" => "Unknown device",
      "Mozilla/5.0 (Windows NT 10.0) AppleWebKit Chrome/120 Safari/537 Edg/120" => "Edge on Windows",
      "Mozilla/5.0 (X11; Linux x86_64) Chrome/120 Safari/537 OPR/105" => "Opera on Linux",
      "Opera/9.80 (Windows NT 6.1)" => "Opera on Windows",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 14.0) Gecko Firefox/121.0" => "Firefox on macOS",
      "Mozilla/5.0 (Linux; Android 14) Chrome/120 Mobile Safari/537" => "Chrome on Android",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Version/17.0 Safari/604.1" => "Safari on iOS",
      "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) Safari/604.1" => "Safari on iOS",
      "curl/8.4.0" => "Command line",
      "Wget/1.21" => "Command line",
      "Rails Testing" => "Test browser",
      "SomethingElse/1.0" => "Browser"
    }.each do |ua, label|
      it "labels #{ua.inspect} as #{label.inspect}" do
        expect(helper.device_label(ua)).to eq(label)
      end
    end
  end

  describe "#audit_tone" do
    {
      "login.succeeded" => :success, "email.verified" => :success, "mfa.enabled" => :success,
      "account.unlocked" => :success, "invitation.accepted" => :success,
      "login.failed" => :danger, "login.blocked" => :danger, "account.locked" => :danger,
      "mfa.disabled" => :danger, "session.revoked" => :danger,
      "password.changed" => :warning, "password.reset_requested" => :warning, "mfa.recovery_code_used" => :warning,
      "logout" => :neutral, "user.registered" => :neutral
    }.each do |action, tone|
      it("is #{tone} for #{action}") { expect(helper.audit_tone(action)).to eq(tone) }
    end
  end
end
