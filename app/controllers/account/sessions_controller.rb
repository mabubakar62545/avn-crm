class Account::SessionsController < ApplicationController
  def index
    @sessions = policy_scope(Session).order(last_active_at: :desc)
  end

  def destroy
    session_record = authorize policy_scope(Session).find(params[:id])
    session_record.destroy
    AuditEvent.record("session.revoked", user: Current.user, scope: "single")
    redirect_to account_sessions_path, notice: "Device signed out.", status: :see_other
  end

  def others
    authorize Session
    policy_scope(Session).where.not(id: Current.session.id).destroy_all
    AuditEvent.record("session.revoked", user: Current.user, scope: "others")
    redirect_to account_sessions_path, notice: "All other devices signed out.", status: :see_other
  end
end
