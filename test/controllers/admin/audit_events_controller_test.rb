require "test_helper"

class Admin::AuditEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    AuditEvent.record("login.failed", user: users(:member), attempted_email: users(:member).email_address)
    AuditEvent.record("user.registered", user: users(:manager))
  end

  test "admins see the audit log" do
    sign_in_as users(:admin)
    get admin_audit_events_path

    assert_response :success
    assert_select "#audit_events tbody tr", minimum: 2
  end

  test "can filter by event and user" do
    sign_in_as users(:admin)

    get admin_audit_events_path(event: "user.registered")
    assert_select "#audit_events tbody tr", 1

    get admin_audit_events_path(user_id: users(:member).id)
    assert_select "#audit_events tbody tr", 1
  end

  test "managers and members are refused" do
    [ :manager, :member ].each do |name|
      sign_in_as users(name)
      get admin_audit_events_path
      assert_redirected_to root_path
    end
  end
end
