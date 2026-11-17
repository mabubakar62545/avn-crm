require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "clients cannot list users" do
    sign_in_as users(:client)
    get admin_users_path
    assert_redirected_to root_path
  end

  test "managers can list and view users but not change them" do
    sign_in_as users(:manager)

    get admin_users_path
    assert_response :success
    assert_select "#users tbody tr", User.count

    get admin_user_path(users(:client))
    assert_response :success
    assert_select "#change_role_form", count: 0

    patch admin_user_path(users(:client)), params: { user: { role: "admin" } }
    assert_equal "client", users(:client).reload.role
  end

  test "admins can change another user's role" do
    sign_in_as users(:admin)

    patch admin_user_path(users(:client)), params: { user: { role: "manager" } }
    assert_redirected_to admin_user_path(users(:client))
    assert_equal "manager", users(:client).reload.role
    assert AuditEvent.exists?(action: "role.changed", user_id: users(:client).id)
  end

  test "admins cannot change their own role" do
    admin = users(:admin)
    sign_in_as admin

    patch admin_user_path(admin), params: { user: { role: "client" } }
    assert_equal "admin", admin.reload.role
  end

  test "an invalid role is rejected" do
    sign_in_as users(:admin)
    patch admin_user_path(users(:client)), params: { user: { role: "superuser" } }
    assert_equal "client", users(:client).reload.role
  end

  test "admins can unlock an account" do
    sign_in_as users(:admin)
    get admin_user_path(users(:locked))
    assert_select "form[action='#{unlock_admin_user_path(users(:locked))}']"

    patch unlock_admin_user_path(users(:locked))
    assert_not users(:locked).reload.locked?
  end

  test "admins can sign a user out everywhere" do
    client = users(:client)
    2.times { client.sessions.create! }
    sign_in_as users(:admin)

    delete revoke_sessions_admin_user_path(client)
    assert_empty client.sessions.reload
  end
end
