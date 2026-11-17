require "rails_helper"

RSpec.describe "Admin: audit log" do
  let(:admin) { create(:user, :admin) }
  let(:client) { create(:user) }
  let(:manager) { create(:user, :manager) }

  before do
    AuditEvent.record("login.failed", user: client, attempted_email: client.email_address)
    AuditEvent.record("password.reset_requested", user: manager)
  end

  def rows = response.parsed_body.css("#audit_events tbody tr")

  it "requires sign-in" do
    get admin_audit_events_path
    expect(response).to redirect_to(new_session_path)
  end

  it "shows admins every event" do
    sign_in_as(admin)
    get admin_audit_events_path
    expect(response).to have_http_status(:ok)
    expect(rows.size).to eq(AuditEvent.count)
  end

  it "filters by event type" do
    sign_in_as(admin)
    get admin_audit_events_path(event: "password.reset_requested")
    expect(rows.size).to eq(1)
  end

  it "filters by user" do
    sign_in_as(admin)
    get admin_audit_events_path(user_id: client.id)
    expect(rows.size).to eq(AuditEvent.where(user_id: client.id).count)
    expect(response.body).to include("for #{client.email_address}")
  end

  it "refuses managers and clients" do
    [ manager, client ].each do |user|
      sign_in_as(user)
      get admin_audit_events_path
      expect(response).to redirect_to(root_path)
    end
  end
end
