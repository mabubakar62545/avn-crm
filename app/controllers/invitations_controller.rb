class InvitationsController < ApplicationController
  skip_authorization_checks
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :update,
             with: -> { redirect_to new_session_path, alert: "Try again later." }
  before_action :set_user_by_token

  def show; end

  def update
    if @user.accept_invitation(password: params[:password].to_s, password_confirmation: params[:password_confirmation].to_s)
      AuditEvent.record("invitation.accepted", user: @user, via: "password")
      flash[:notice] = "Welcome to AVN CRM! Your account is ready."
      complete_sign_in @user, via: "invitation"
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_token_for(:invitation, params[:token])
      redirect_to new_session_path, alert: "That invitation link is invalid or has expired. Ask an admin to send a new one." unless @user
    end
end
