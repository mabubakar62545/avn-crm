class Admin::InvitationsController < ApplicationController
  def create
    authorize User, :invite?
    attrs = params.expect(invitation: %i[email_address role])
    user  = User.invite!(email_address: attrs[:email_address], role: attrs[:role], invited_by: Current.user)
    redirect_to admin_user_path(user), notice: "Invitation sent to #{user.email_address}.", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_users_path, alert: e.record.errors.full_messages.to_sentence, status: :see_other
  end
end
