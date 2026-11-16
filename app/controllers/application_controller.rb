class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Every action must either `authorize` a record, or (for index actions) use
  # `policy_scope`. Controllers with no record to protect (sign in, sign up,
  # password reset...) opt out with `skip_authorization_checks`.
  #
  # A single callback is used instead of `only: :index` / `except: :index`,
  # because `raise_on_missing_callback_actions` makes those options blow up in
  # controllers that have no index action.
  after_action :verify_pundit_usage
  before_action :set_request_details

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  def self.skip_authorization_checks
    skip_after_action :verify_pundit_usage
  end

  private
    def pundit_user = Current.user

    def verify_pundit_usage
      action_name == "index" ? verify_policy_scoped : verify_authorized
    end

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
