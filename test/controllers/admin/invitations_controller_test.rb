require "test_helper"

class Admin::InvitationsControllerTest < ActionDispatch::IntegrationTest
  def invite(email: "jane@avn.example", role: "manager")
    post admin_invitations_path, params: { invitation: { email_address: email, role: } }
  end

  test "admins can invite an employee" do
    sign_in_as users(:admin)

    assert_difference -> { User.count }, 1 do
      invite
    end
    user = User.find_by!(email_address: "jane@avn.example")
    assert_redirected_to admin_user_path(user)
    assert_equal "manager", user.role
    assert_equal users(:admin), user.invited_by
    assert user.invitation_pending?
    assert_enqueued_email_with UserMailer, :invitation, args: [ user ]
    assert AuditEvent.exists?(action: "user.invited", user_id: user.id, actor_id: users(:admin).id)
    assert_not AuditEvent.exists?(action: "user.registered", user_id: user.id)
  end

  test "managers and clients cannot invite" do
    [ :manager, :client ].each do |name|
      sign_in_as users(name)
      assert_no_difference -> { User.count } do
        invite(role: "admin")
      end
    end
  end

  test "an existing email or bad role is refused" do
    sign_in_as users(:admin)

    assert_no_difference -> { User.count } do
      invite(email: users(:client).email_address)
      invite(email: "x@avn.example", role: "superuser")
    end
    assert_redirected_to admin_users_path
  end

  test "admins can resend a pending invitation" do
    user = User.invite!(email_address: "jane@avn.example", role: "manager")
    sign_in_as users(:admin)

    post resend_invitation_admin_user_path(user)
    assert_redirected_to admin_user_path(user)
    assert_enqueued_email_with UserMailer, :invitation, args: [ user ]
  end

  test "resend is refused once the invitation was accepted" do
    sign_in_as users(:admin)
    post resend_invitation_admin_user_path(users(:client))
    assert_no_enqueued_emails
  end

  test "the users page shows the invite form only to admins" do
    sign_in_as users(:admin)
    get admin_users_path
    assert_select "form#invite_user_form"

    sign_in_as users(:manager)
    get admin_users_path
    assert_select "form#invite_user_form", count: 0
  end
end
