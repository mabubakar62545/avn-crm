require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  test "scope" do
    assert_equal User.count, UserPolicy::Scope.new(users(:manager), User).resolve.count
    assert_equal [ users(:client) ], UserPolicy::Scope.new(users(:client), User).resolve.to_a
  end

  test "only admins can update, and never themselves" do
    assert UserPolicy.new(users(:admin), users(:client)).update?
    assert_not UserPolicy.new(users(:admin), users(:admin)).update?
    assert_not UserPolicy.new(users(:manager), users(:client)).update?
  end
end
