require "rails_helper"

RSpec.describe "Dashboard" do
  def nav_links = response.parsed_body.css("nav a").map(&:text)

  it "requires sign-in" do
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "shows the user's own summary and only their own activity" do
    user = create(:user)
    other = create(:user)
    AuditEvent.record("login.failed", user: other)
    sign_in_as(user)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(user.email_address)
    expect(response.body).not_to include(other.email_address)
    expect(response.parsed_body.css("#recent_activity li").text).to include("user.registered")
    expect(response.parsed_body.css("#recent_activity li").text).not_to include("login.failed")
  end

  it "shows admins every admin link" do
    sign_in_as(create(:user, :admin))
    get root_path
    expect(nav_links).to include("Users", "Audit log")
  end

  it "shows managers Users but not the audit log" do
    sign_in_as(create(:user, :manager))
    get root_path
    expect(nav_links).to include("Users")
    expect(nav_links).not_to include("Audit log")
  end

  it "shows clients neither" do
    sign_in_as(create(:user, :client))
    get root_path
    expect(nav_links).to eq([ "Dashboard", "Security" ])
  end
end
