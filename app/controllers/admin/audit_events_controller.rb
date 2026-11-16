# app/controllers/admin/audit_events_controller.rb
class Admin::AuditEventsController < ApplicationController
  def index
    authorize AuditEvent
    @events = policy_scope(AuditEvent).recent.includes(:actor).limit(200)
    @events = @events.where(user_id: params[:user_id]) if params[:user_id].present?
    @events = @events.where(action: params[:event]) if params[:event].present?
  end
end