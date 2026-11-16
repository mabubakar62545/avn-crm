# app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  before_action :set_user, except: :index

  def index
    authorize User
    @users = policy_scope(User).order(:email_address)
  end

  def show; end

  def update
    if @user.update(permitted_attributes(@user))
      redirect_to admin_user_path(@user), notice: "Role updated to #{@user.role}."
    else
      redirect_to admin_user_path(@user), alert: @user.errors.full_messages.to_sentence
    end
  end

  def unlock
    @user.update_columns(locked_until: nil, failed_login_attempts: 0)
    AuditEvent.record("account.unlocked", user: @user)
    redirect_to admin_user_path(@user), notice: "Account unlocked."
  end

  def revoke_sessions
    @user.sessions.destroy_all
    AuditEvent.record("sessions.revoked_by_admin", user: @user)
    redirect_to admin_user_path(@user), notice: "Signed out of all devices.", status: :see_other
  end

  private
    def set_user
      @user = authorize policy_scope(User).find(params[:id])
    end
end