require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "requires sign-in" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "shows the dashboard" do
    sign_in_as users(:member)
    get root_path

    assert_response :success
    assert_select "#account_summary"
    assert_select ".nav a", text: "Users", count: 0
    assert_select ".nav a", text: "Audit log", count: 0
  end

  test "admins see admin navigation" do
    sign_in_as users(:admin)
    get root_path

    assert_select ".nav a", text: "Users"
    assert_select ".nav a", text: "Audit log"
  end

  test "managers see users but not the audit log" do
    sign_in_as users(:manager)
    get root_path

    assert_select ".nav a", text: "Users"
    assert_select ".nav a", text: "Audit log", count: 0
  end
end
