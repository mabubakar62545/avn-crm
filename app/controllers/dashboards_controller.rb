class DashboardsController < ApplicationController
  skip_authorization_checks

  def show
    @user = Current.user
    @active_sessions = @user.sessions.count
    @recent_events = AuditEvent.where(user_id: @user.id).recent.limit(5)
  end
end
