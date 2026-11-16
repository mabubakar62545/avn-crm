require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  test "scope" do
    assert_equal User.count, UserPolicy::Scope.new(users(:manager), User).resolve.count
    assert_equal [ users(:member) ], UserPolicy::Scope.new(users(:member), User).resolve.to_a
  end

  test "only admins can update, and never themselves" do
    assert UserPolicy.new(users(:admin), users(:member)).update?
    assert_not UserPolicy.new(users(:admin), users(:admin)).update?
    assert_not UserPolicy.new(users(:manager), users(:member)).update?
  end
end
