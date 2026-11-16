# app/controllers/account/two_factors_controller.rb
class Account::TwoFactorsController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: %i[create destroy]
  before_action :redirect_if_enabled, only: %i[new create]

  def new
    session[:pending_otp_secret] ||= ROTP::Base32.random
    @secret = session[:pending_otp_secret]
    @qr_svg = RQRCode::QRCode.new(Current.user.otp_provisioning_uri(@secret))
                             .as_svg(module_size: 4, use_path: true)
  end

  def create
    secret = session[:pending_otp_secret]

    if Current.user.verify_otp(params[:code], secret: secret)
      @recovery_codes = Current.user.enable_otp!(secret)
      session.delete(:pending_otp_secret)
      no_store
      render :recovery_codes
    else
      redirect_to new_account_two_factor_path, alert: "That code didn't match. Try again."
    end
  end

  def destroy
    user = Current.user
    code = params[:code].to_s

    if user.authenticate(params[:password]) && (user.verify_otp(code) || user.consume_recovery_code(code))
      user.disable_otp!
      UserMailer.two_factor_disabled(user).deliver_later
      redirect_to account_sessions_path, notice: "Two-factor authentication turned off."
    else
      redirect_to account_sessions_path, alert: "Password or code was incorrect."
    end
  end

  private
    def redirect_if_enabled
      redirect_to account_sessions_path, notice: "Two-factor is already on." if Current.user.otp_enabled?
    end
end