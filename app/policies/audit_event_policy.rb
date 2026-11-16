# app/policies/audit_event_policy.rb
class AuditEventPolicy < ApplicationPolicy
  def index? = user.admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = user.admin? ? scope.all : scope.none
  end
end