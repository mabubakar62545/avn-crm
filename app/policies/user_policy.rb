class UserPolicy < ApplicationPolicy
  def index?           = user.at_least?(:manager)
  def show?            = index?
  def update?          = user.admin? && !self?
  def unlock?          = user.admin?
  def revoke_sessions? = user.admin?

  def permitted_attributes = update? ? %i[role] : []

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.at_least?(:manager) ? scope.all : scope.where(id: user.id)
    end
  end

  private
    def self? = record == user
end
