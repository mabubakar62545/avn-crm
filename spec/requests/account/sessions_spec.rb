require "rails_helper"

RSpec.describe "Account: signed-in devices" do
  let(:user) { create(:user) }
  let!(:current) { sign_in_as(user) }
  let!(:other_device) { create(:session, user:) }
  let!(:someone_elses) { create(:session) }

  it "requires sign-in" do
    sign_out
    get account_sessions_path
    expect(response).to redirect_to(new_session_path)
  end

  it "lists only my devices and marks this one" do
    get account_sessions_path

    expect(response).to have_http_status(:ok)
    ids = response.parsed_body.css("#devices tbody tr").map { _1["id"] }
    expect(ids).to contain_exactly("session_#{current.id}", "session_#{other_device.id}")
    expect(response.parsed_body.css("#session_#{current.id}").text).to include("This device")
  end

  it "signs out another of my devices (audited)" do
    delete account_session_path(other_device)

    expect(response).to redirect_to(account_sessions_path)
    expect(Session.exists?(other_device.id)).to be(false)
    expect(AuditEvent.find_by!(action: "session.revoked", user_id: user.id).metadata).to eq("scope" => "single")
  end

  it "cannot touch another user's device" do
    delete account_session_path(someone_elses)
    expect(response).to have_http_status(:not_found)
    expect(Session.exists?(someone_elses.id)).to be(true)
  end

  it "refuses to sign out the current device this way" do
    delete account_session_path(current)
    expect(response).to redirect_to(root_path)
    expect(Session.exists?(current.id)).to be(true)
  end

  it "signs out every other device, keeping this one and other users' (audited)" do
    delete others_account_sessions_path

    expect(response).to redirect_to(account_sessions_path)
    expect(user.sessions.reload).to contain_exactly(current)
    expect(Session.exists?(someone_elses.id)).to be(true)
    expect(AuditEvent.find_by!(action: "session.revoked", user_id: user.id).metadata).to eq("scope" => "others")
  end
end
