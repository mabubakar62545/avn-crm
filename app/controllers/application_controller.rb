class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index
  before_action :set_request_details

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  def self.skip_authorization_checks
    skip_after_action :verify_authorized, raise: false
    skip_after_action :verify_policy_scoped, raise: false
  end

  private
    def pundit_user = Current.user

    def forbidden
      respond_to do |format|
        format.html { redirect_back_or_to root_path, alert: "You're not allowed to do that." }
        format.any  { head :forbidden }
      end
    end

    def set_request_details
      Current.ip_address = request.remote_ip
      Current.user_agent = request.user_agent
      Current.request_id = request.request_id
    end
end