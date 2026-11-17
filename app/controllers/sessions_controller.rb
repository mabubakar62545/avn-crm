class SessionsController < ApplicationController
  skip_authorization_checks
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  GENERIC_FAILURE = "Try another email address or password."

  def new
    redirect_to root_path if authenticated?
  end

  def create
    # Both keys always present: authenticate_by raises (500) if the password key is missing.
    user = User.authenticate_by(email_address: params[:email_address].to_s, password: params[:password].to_s)

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
      start_two_factor_challenge user
    else
      complete_sign_in user
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other, notice: "You have been signed out."
  end
end
