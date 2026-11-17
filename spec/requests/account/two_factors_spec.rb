require "rails_helper"

RSpec.describe "Account: two-factor setup" do
  let(:user) { create(:user) }

  it "requires sign-in" do
    get new_account_two_factor_path
    expect(response).to redirect_to(new_session_path)
    post account_two_factor_path, params: { code: "123456" }
    expect(response).to redirect_to(new_session_path)
    delete account_two_factor_path
    expect(response).to redirect_to(new_session_path)
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows a QR code and the secret, and keeps the same secret on reload" do
      get new_account_two_factor_path
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css(".qr svg")).to be_present
      secret = session[:pending_otp_secret]
      expect(response.parsed_body.css("#otp_secret").text.delete(" ")).to eq(secret)

      get new_account_two_factor_path
      expect(session[:pending_otp_secret]).to eq(secret)
    end

    it "enables 2FA with a valid code and shows the recovery codes once, uncached" do
      get new_account_two_factor_path
      secret = session[:pending_otp_secret]

      post account_two_factor_path, params: { code: current_otp(secret) }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("#recovery_codes li").size).to eq(User::RECOVERY_CODE_COUNT)
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(user.reload).to be_otp_enabled
      expect(session[:pending_otp_secret]).to be_nil
    end

    it "does not enable 2FA with a wrong code" do
      get new_account_two_factor_path
      post account_two_factor_path, params: { code: "not-a-code" }

      expect(response).to redirect_to(new_account_two_factor_path)
      expect(flash[:alert]).to match(/didn't match/)
      expect(user.reload).not_to be_otp_enabled
    end

    it "does not enable 2FA without first visiting setup (no pending secret)" do
      post account_two_factor_path, params: { code: "123456" }
      expect(response).to redirect_to(new_account_two_factor_path)
      expect(user.reload).not_to be_otp_enabled
    end

    it "redirects when 2FA is already on" do
      enable_two_factor(user)

      get new_account_two_factor_path
      expect(response).to redirect_to(account_sessions_path)

      post account_two_factor_path, params: { code: "123456" }
      expect(response).to redirect_to(account_sessions_path)
    end

    describe "turning 2FA off" do
      let!(:otp) { enable_two_factor(user) }
      let(:secret) { otp.first }

      it "needs the right password" do
        delete account_two_factor_path, params: { password: "wrong", code: current_otp(secret) }
        expect(response).to redirect_to(account_sessions_path)
        expect(flash[:alert]).to eq("Password or code was incorrect.")
        expect(user.reload).to be_otp_enabled
      end

      it "needs a valid code" do
        delete account_two_factor_path, params: { password: AuthenticationHelpers::PASSWORD, code: "not-a-code" }
        expect(user.reload).to be_otp_enabled
      end

      it "works with the password and an authenticator code, and emails the user" do
        expect {
          delete account_two_factor_path, params: { password: AuthenticationHelpers::PASSWORD, code: current_otp(secret) }
        }.to have_enqueued_mail(UserMailer, :two_factor_disabled)

        expect(response).to redirect_to(account_sessions_path)
        expect(user.reload).not_to be_otp_enabled
      end

      it "works with the password and a recovery code" do
        delete account_two_factor_path, params: { password: AuthenticationHelpers::PASSWORD, code: otp.last.first }
        expect(user.reload).not_to be_otp_enabled
      end

      it "is rate-limited" do
        5.times { delete account_two_factor_path, params: { password: "wrong", code: "x" } }
        delete account_two_factor_path, params: { password: AuthenticationHelpers::PASSWORD, code: current_otp(secret) }
        expect(response).to have_http_status(:too_many_requests)
        expect(user.reload).to be_otp_enabled
      end
    end

    it "warns when recovery codes are running low" do
      _secret, codes = enable_two_factor(user)
      codes.first(7).each { user.consume_recovery_code(_1) }
      get account_sessions_path
      expect(response.body).to include("running low on recovery codes")
    end
  end

  context "when the user only signs in with Google" do
    let(:user) { create(:user, :sso_only) }

    it "turns off 2FA with just a code (there is no password to confirm)" do
      sign_in_as(user)
      secret, = enable_two_factor(user)

      get account_sessions_path
      expect(response.parsed_body.css("#disable_two_factor_form input[name=password]")).to be_empty

      delete account_two_factor_path, params: { code: "not-a-code" }
      expect(user.reload).to be_otp_enabled

      delete account_two_factor_path, params: { code: current_otp(secret) }
      expect(user.reload).not_to be_otp_enabled
    end
  end
end
