class SessionsController < ApplicationController
  skip_authorization_checks
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  GENERIC_FAILURE = "Try another email address or password."

  def new
    redirect_to root_path if authenticated?
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))

    if user.nil?
      candidate = User.find_by(email_address: params[:email_address])
      candidate&.register_failed_login!
      AuditEvent.record("login.failed", user: candidate, attempted_email: params[:email_address].to_s.truncate(254))
      redirect_to new_session_path, alert: GENERIC_FAILURE
    elsif user.locked?
      AuditEvent.record("login.blocked", user:, reason: "locked")
      redirect_to new_session_path, alert: GENERIC_FAILURE
    elsif !user.verified?
      redirect_to new_email_verification_path, alert: "Please confirm your email first."
    elsif user.otp_enabled?
      session[:pending_mfa] = { "user_id" => user.id, "expires_at" => 5.minutes.from_now.to_i }
      redirect_to new_two_factor_challenge_path
    else
      complete_sign_in user
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other, notice: "You have been signed out."
  end
end
