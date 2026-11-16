class RegistrationsController < ApplicationController
  skip_authorization_checks
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_registration_path, alert: "Too many attempts. Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if (existing = User.find_by(email_address: @user.email_address))
      UserMailer.already_registered(existing).deliver_later
      redirect_to new_session_path, notice: check_email_notice
    elsif @user.save
      UserMailer.email_verification(@user).deliver_later
      redirect_to new_session_path, notice: check_email_notice
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def check_email_notice = "Check your email to confirm your account."

    def registration_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end
end
