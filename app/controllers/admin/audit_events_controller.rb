class Admin::AuditEventsController < ApplicationController
  def index
    authorize AuditEvent
    @events = policy_scope(AuditEvent).recent.includes(:actor)
    @events = @events.where(user_id: params[:user_id]) if params[:user_id].present?
    @events = @events.where(action: params[:event]) if params[:event].present?
    @events = @events.limit(200)

    @filtered_user = User.find_by(id: params[:user_id]) if params[:user_id].present?
    @actions = policy_scope(AuditEvent).distinct.order(:action).pluck(:action)
  end
end
