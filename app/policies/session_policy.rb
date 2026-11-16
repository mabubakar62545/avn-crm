class SessionPolicy < ApplicationPolicy
  # A user may only see and sign out their own devices, never the one in use
  # (that's what "Sign out" in the header is for).
  def destroy? = record.user_id == user.id && record != Current.session
  def others?  = true

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(user_id: user.id)
  end
end
