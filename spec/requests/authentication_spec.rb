require "rails_helper"

# The Authentication concern, exercised through a protected page (the dashboard).
RSpec.describe "Authentication" do
  let(:user) { create(:user) }

  it "redirects anonymous visitors to sign in and remembers where they were going" do
    get account_sessions_path
    expect(response).to redirect_to(new_session_path)

    sign_in_with_password(user)
    expect(response).to redirect_to(account_sessions_url)
  end

  it "only returns to the remembered page once" do
    get account_sessions_path
    sign_in_with_password(user)
    delete session_path

    sign_in_with_password(user)
    expect(response).to redirect_to(root_url)
  end

  it "lets a signed-in user through and records their activity" do
    session = sign_in_as(user)
    session.update_columns(last_active_at: 10.minutes.ago)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(session.reload.last_active_at).to be_within(1.second).of(Time.current)
  end

  it "ignores a cookie for a session that no longer exists" do
    session = sign_in_as(user)
    session.destroy!

    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "ignores a tampered (unsigned) session cookie" do
    session = user.sessions.create!
    cookies["session_id"] = session.id.to_s

    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "ends a session that has been idle too long" do
    session = sign_in_as(user)
    session.update_columns(last_active_at: (Session::IDLE_TIMEOUT + 1.minute).ago)

    get root_path

    expect(response).to redirect_to(new_session_path)
    expect(Session.exists?(session.id)).to be(false)
    expect(cookies["session_id"]).to be_blank
  end

  it "ends a session older than the absolute timeout, even if active" do
    session = sign_in_as(user)
    session.update_columns(created_at: (Session::ABSOLUTE_TIMEOUT + 1.minute).ago)

    get root_path

    expect(response).to redirect_to(new_session_path)
    expect(Session.exists?(session.id)).to be(false)
  end

  it "sets a signed, HttpOnly, SameSite=Lax session cookie on sign-in" do
    sign_in_with_password(user)

    set_cookie = Array(response.headers["Set-Cookie"]).join("\n")
    expect(set_cookie).to match(/session_id=[^;]+;/)
    expect(set_cookie).to match(/httponly/i)
    expect(set_cookie).to match(/samesite=lax/i)
    expect(set_cookie).to match(/expires=/i)
  end

  it "records the device on the new session" do
    post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD },
                       headers: { "User-Agent" => "Firefox/120.0", "REMOTE_ADDR" => "198.51.100.4" }

    expect(user.sessions.sole).to have_attributes(user_agent: "Firefox/120.0", ip_address: "198.51.100.4")
  end
end
