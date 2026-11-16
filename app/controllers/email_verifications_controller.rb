# app/controllers/email_verifications_controller.rb
class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 10.minutes, only: :create,
             with: -> { redirect_to new_email_verification_path, alert: "Try again later." }
  before_action :set_user_by_token, only: %i[show update]

  def new; end

  def create
    user = User.find_by(email_address: params[:email_address])
    UserMailer.email_verification(user).deliver_later if user && !user.verified?
    redirect_to new_session_path, notice: "If that account needs confirming, we've sent a new link."
  end

  def show; end

  def update
    @user.verify! unless @user.verified?
    redirect_to new_session_path, notice: "Email confirmed. You can now sign in."
  end

  private
    def set_user_by_token
      @user = User.find_by_token_for(:email_verification, params[:token])
      redirect_to new_email_verification_path, alert: "That link is invalid or has expired." unless @user
    end
end