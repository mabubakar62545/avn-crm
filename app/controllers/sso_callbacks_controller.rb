# app/controllers/sso_callbacks_controller.rb
class SsoCallbacksController < ApplicationController
  allow_unauthenticated_access
  skip_authorization_checks

  def create
    auth = request.env["omniauth.auth"]
    authenticated? ? link_identity(auth) : sign_in_with(auth)
  end

  def failure
    AuditEvent.record("sso.failed", reason: params[:message].to_s.truncate(100))
    redirect_to (authenticated? ? account_sessions_path : new_session_path), alert: "Single sign-on failed. Please try again."
  end

  private
    def sign_in_with(auth)
      result = SsoSignIn.new(auth).call

      if result.user.nil?
        AuditEvent.record("sso.failed", provider: auth.provider, attempted_email: auth.info.email, reason: result.error)
        redirect_to new_session_path, alert: result.error
      elsif result.user.locked?
        AuditEvent.record("login.blocked", user: result.user, reason: "locked", via: "sso")
        redirect_to new_session_path, alert: SessionsController::GENERIC_FAILURE
      elsif result.user.otp_enabled?
        start_two_factor_challenge result.user, via: "sso:#{auth.provider}"
      else
        flash[:notice] = "Welcome! Your account has been created." if result.created
        flash[:notice] = "Welcome to AVN CRM! Your invitation has been accepted." if result.accepted_invitation
        complete_sign_in result.user, via: "sso:#{auth.provider}"
      end
    end

    # A signed-in user came back from the provider: attach that provider
    # account to them so they can use it to sign in next time.
    def link_identity(auth)
      user     = Current.user
      provider = auth.provider.to_s
      uid      = auth.uid.to_s
      existing = Identity.find_by(provider:, uid:)
      name     = provider.titleize

      if existing&.user_id == user.id
        notice = "That #{name} account is already linked."
      elsif existing
        AuditEvent.record("sso.link_failed", user:, provider:, reason: "linked_to_another_user")
        alert = "That #{name} account is already linked to a different user."
      elsif user.identities.exists?(provider:)
        alert = "You already have a #{name} account linked. Unlink it first to link a different one."
      else
        user.identities.create!(provider:, uid:, email: auth.info.email.to_s.strip.downcase)
        AuditEvent.record("sso.linked", user:, provider:)
        notice = "#{name} account linked. You can now use it to sign in."
      end

      redirect_to account_sessions_path(anchor: "sign_in_methods"), notice:, alert:
    end
end
