require "rails_helper"

RSpec.describe "Two-factor challenges" do
  let(:user) { create(:user) }
  let!(:otp) { enable_two_factor(user) }
  let(:secret) { otp.first }
  let(:codes) { otp.last }

  def start_sign_in
    sign_in_with_password(user)
    expect(response).to redirect_to(new_two_factor_challenge_path)
  end

  def answer(code) = post two_factor_challenge_path, params: { code: }

  describe "without a pending sign-in" do
    it "sends you back to sign in (both actions)" do
      get new_two_factor_challenge_path
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Please sign in again.")

      answer(current_otp(secret))
      expect(response).to redirect_to(new_session_path)
      expect(user.sessions).to be_empty
    end
  end

  it "shows the code form" do
    start_sign_in
    get new_two_factor_challenge_path
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.css("form#two_factor_challenge_form")).to be_present
  end

  it "expires the pending sign-in after 5 minutes" do
    start_sign_in
    travel 5.minutes + 1.second

    answer(current_otp(secret))

    expect(response).to redirect_to(new_session_path)
    expect(session[:pending_mfa]).to be_nil
    expect(user.sessions).to be_empty
  end

  it "refuses if the account was locked meanwhile" do
    start_sign_in
    user.update_columns(locked_until: 1.hour.from_now)

    answer(current_otp(secret))

    expect(response).to redirect_to(new_session_path)
    expect(session[:pending_mfa]).to be_nil
    expect(user.sessions).to be_empty
  end

  it "refuses if the account was deleted meanwhile" do
    start_sign_in
    user.destroy!

    get new_two_factor_challenge_path
    expect(response).to redirect_to(new_session_path)
  end

  it "completes sign-in with a valid authenticator code" do
    start_sign_in

    expect { answer(current_otp(secret)) }.to change(user.sessions, :count).by(1)

    expect(response).to redirect_to(root_url)
    expect(cookies["session_id"]).to be_present
    expect(session[:pending_mfa]).to be_nil
    expect(AuditEvent.where(action: "login.succeeded", user_id: user.id).sole.metadata).to eq("via" => "password", "mfa" => true)
  end

  it "rejects a replayed authenticator code" do
    code = current_otp(secret)
    start_sign_in
    answer(code)
    delete session_path

    start_sign_in
    answer(code)
    expect(response).to redirect_to(new_two_factor_challenge_path)
  end

  it "completes sign-in with a recovery code once, emails the user and audits" do
    start_sign_in

    expect { answer(codes.first) }.to have_enqueued_mail(UserMailer, :recovery_code_used)

    expect(response).to redirect_to(root_url)
    expect(user.recovery_codes.unused.count).to eq(User::RECOVERY_CODE_COUNT - 1)
    expect(AuditEvent.where(action: "mfa.recovery_code_used", user_id: user.id)).to exist

    delete session_path
    start_sign_in
    answer(codes.first)
    expect(response).to redirect_to(new_two_factor_challenge_path)
  end

  it "rejects a wrong code, counts it and audits" do
    start_sign_in

    answer("not-a-code")

    expect(response).to redirect_to(new_two_factor_challenge_path)
    expect(flash[:alert]).to eq("Invalid code. Try again.")
    expect(cookies["session_id"]).to be_blank
    expect(user.reload.failed_login_attempts).to eq(1)
    expect(AuditEvent.where(action: "mfa.failed", user_id: user.id)).to exist
  end

  it "rejects a blank code" do
    start_sign_in
    post two_factor_challenge_path
    expect(response).to redirect_to(new_two_factor_challenge_path)
  end

  it "locks the account and abandons the sign-in after too many wrong codes" do
    start_sign_in
    user.update_columns(failed_login_attempts: User::MAX_FAILED_LOGINS - 1)

    answer("not-a-code")

    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to eq(SessionsController::GENERIC_FAILURE)
    expect(session[:pending_mfa]).to be_nil
    expect(user.reload).to be_locked
  end

  it "keeps the SSO provider as the sign-in method" do
    create(:identity, user:, uid: "g-1")
    return_from_google(uid: "g-1", email: user.email_address)
    expect(response).to redirect_to(new_two_factor_challenge_path)

    answer(current_otp(secret))

    expect(AuditEvent.where(action: "login.succeeded").last.metadata["via"]).to eq("sso:google")
  end

  it "rate-limits code guesses" do
    start_sign_in
    10.times { answer("not-a-code") }

    answer(current_otp(secret))

    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to eq("Try again later.")
    expect(user.sessions).to be_empty
  end
end
