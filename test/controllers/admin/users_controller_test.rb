require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "members cannot list users" do
    sign_in_as users(:member)
    get admin_users_path
    assert_redirected_to root_path
  end

  test "managers can list and view users but not change them" do
    sign_in_as users(:manager)

    get admin_users_path
    assert_response :success
    assert_select "#users tbody tr", User.count

    get admin_user_path(users(:member))
    assert_response :success
    assert_select "#change_role_form", count: 0

    patch admin_user_path(users(:member)), params: { user: { role: "admin" } }
    assert_equal "member", users(:member).reload.role
  end

  test "admins can change another user's role" do
    sign_in_as users(:admin)

    patch admin_user_path(users(:member)), params: { user: { role: "manager" } }
    assert_redirected_to admin_user_path(users(:member))
    assert_equal "manager", users(:member).reload.role
    assert AuditEvent.exists?(action: "role.changed", user_id: users(:member).id)
  end

  test "admins cannot change their own role" do
    admin = users(:admin)
    sign_in_as admin

    patch admin_user_path(admin), params: { user: { role: "member" } }
    assert_equal "admin", admin.reload.role
  end

  test "an invalid role is rejected" do
    sign_in_as users(:admin)
    patch admin_user_path(users(:member)), params: { user: { role: "superuser" } }
    assert_equal "member", users(:member).reload.role
  end

  test "admins can unlock an account" do
    sign_in_as users(:admin)
    get admin_user_path(users(:locked))
    assert_select "form[action='#{unlock_admin_user_path(users(:locked))}']"

    patch unlock_admin_user_path(users(:locked))
    assert_not users(:locked).reload.locked?
  end

  test "admins can sign a user out everywhere" do
    member = users(:member)
    2.times { member.sessions.create! }
    sign_in_as users(:admin)

    delete revoke_sessions_admin_user_path(member)
    assert_empty member.sessions.reload
  end
end
