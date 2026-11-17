class Account::IdentitiesController < ApplicationController
  # Records are scoped to Current.user, so there is nothing for Pundit to check.
  skip_authorization_checks

  def destroy
    identity = Current.user.identities.find(params[:id])

    unless Current.user.can_unlink_identity?
      return redirect_to account_sessions_path(anchor: "sign_in_methods"), status: :see_other,
                         alert: "Set a password before unlinking #{identity.provider.titleize}, " \
                                "or you won't be able to sign in."
    end

    identity.destroy
    AuditEvent.record("sso.unlinked", user: Current.user, provider: identity.provider)
    redirect_to account_sessions_path(anchor: "sign_in_methods"),
                notice: "#{identity.provider.titleize} account unlinked.", status: :see_other
  end
end
