class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }
  GENERIC_FAILURE = "Try another email address or password."

  def index
    @sessions = Current.user.sessions.order(last_active_at: :desc)
  end

  def destroy
    Current.user.sessions.find(params[:id]).destroy
    redirect_to account_sessions_path, notice: "Device signed out."
  end

  def others
    Current.user.sessions.where.not(id: Current.session.id).destroy_all
    redirect_to account_sessions_path, notice: "All other devices signed out."
  end

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))

    if user.nil?
      User.find_by(email_address: params[:email_address])&.register_failed_login!
      redirect_to new_session_path, alert: GENERIC_FAILURE
    elsif user.locked?
      redirect_to new_session_path, alert: GENERIC_FAILURE
    elsif !user.verified?
      redirect_to new_email_verification_path, alert: "Please confirm your email first."
    else
      user.reset_failed_logins!
      start_new_session_for user
      redirect_to after_authentication_url
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
