class TwoFactorChallengesController < ApplicationController
  skip_authorization_checks
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Try again later." }
  before_action :set_pending_user

  def new; end

  def create
    code = params[:code].to_s

    if @user.verify_otp(code)
      finish_sign_in
    elsif @user.consume_recovery_code(code)
      AuditEvent.record("mfa.recovery_code_used", user: @user)
      UserMailer.recovery_code_used(@user).deliver_later
      finish_sign_in
    else
      AuditEvent.record("mfa.failed", user: @user)
      @user.register_failed_login!
      if @user.reload.locked?
        session.delete(:pending_mfa)
        redirect_to new_session_path, alert: SessionsController::GENERIC_FAILURE
      else
        redirect_to new_two_factor_challenge_path, alert: "Invalid code. Try again."
      end
    end
  end

  private
    def set_pending_user
      pending = session[:pending_mfa]
      @user = User.find_by(id: pending["user_id"]) if pending && pending["expires_at"].to_i > Time.current.to_i

      unless @user && !@user.locked?
        session.delete(:pending_mfa)
        redirect_to new_session_path, alert: "Please sign in again."
      end
    end

    def finish_sign_in
      session.delete(:pending_mfa)
      complete_sign_in @user
    end
end
