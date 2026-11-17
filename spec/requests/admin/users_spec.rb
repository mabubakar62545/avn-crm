require "rails_helper"

RSpec.describe "Admin: users" do
  let(:admin)   { create(:user, :admin) }
  let(:manager) { create(:user, :manager) }
  let(:client)  { create(:user, :client) }
  let(:target)  { create(:user, :client) }

  def expect_forbidden
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq("You're not allowed to do that.")
  end

  describe "anonymous visitors" do
    it "are sent to sign in for every action" do
      get admin_users_path
      expect(response).to redirect_to(new_session_path)
      get admin_user_path(target)
      expect(response).to redirect_to(new_session_path)
      patch admin_user_path(target), params: { user: { role: "admin" } }
      expect(response).to redirect_to(new_session_path)
      patch unlock_admin_user_path(target)
      expect(response).to redirect_to(new_session_path)
      delete revoke_sessions_admin_user_path(target)
      expect(response).to redirect_to(new_session_path)
      post resend_invitation_admin_user_path(target)
      expect(response).to redirect_to(new_session_path)
      expect(target.reload.role).to eq("client")
    end
  end

  describe "clients" do
    before { sign_in_as(client) }

    it "cannot list users" do
      get admin_users_path
      expect_forbidden
    end

    it "cannot view even their own admin page" do
      get admin_user_path(client)
      expect_forbidden
    end

    it "cannot see that other users exist" do
      get admin_user_path(target)
      expect(response).to have_http_status(:not_found)
    end

    it "cannot promote themselves" do
      patch admin_user_path(client), params: { user: { role: "admin" } }
      expect_forbidden
      expect(client.reload.role).to eq("client")
    end

    it "gets a bare 403 for non-HTML requests" do
      get admin_users_path, headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:forbidden)
    end

    it "is sent back where they came from when refused" do
      get admin_users_path, headers: { "Referer" => "http://www.example.com/account/sessions" }
      expect(response).to redirect_to("http://www.example.com/account/sessions")
    end
  end

  describe "managers" do
    before { sign_in_as(manager) }

    it "can list and view users, without the activity log" do
      target
      get admin_users_path
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("#users tbody tr").size).to eq(User.count)

      get admin_user_path(target)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Only admins can change this account.")
      expect(response.parsed_body.css("#audit_events")).to be_empty
    end

    it "cannot change roles, including their own" do
      patch admin_user_path(target), params: { user: { role: "admin" } }
      expect_forbidden
      patch admin_user_path(manager), params: { user: { role: "admin" } }
      expect_forbidden
      expect([ target.reload.role, manager.reload.role ]).to eq(%w[client manager])
    end

    it "cannot unlock, sign others out, or resend invitations" do
      locked = create(:user, :locked)
      invited = create(:user, :invited)
      create(:session, user: target)

      patch unlock_admin_user_path(locked)
      expect_forbidden
      delete revoke_sessions_admin_user_path(target)
      expect_forbidden
      expect { post resend_invitation_admin_user_path(invited) }.not_to have_enqueued_mail

      expect(locked.reload).to be_locked
      expect(target.sessions).not_to be_empty
    end
  end

  describe "admins" do
    before { sign_in_as(admin) }

    it "see the user's details, actions and recent activity" do
      get admin_user_path(target)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("form#change_role_form")).to be_present
      expect(response.parsed_body.css("#audit_events")).to be_present
    end

    it "can change another user's role (audited)" do
      patch admin_user_path(target), params: { user: { role: "manager" } }

      expect(response).to redirect_to(admin_user_path(target))
      expect(flash[:notice]).to eq("Role updated to manager.")
      expect(target.reload.role).to eq("manager")
      expect(AuditEvent.find_by!(action: "role.changed", user_id: target.id).actor).to eq(admin)
    end

    it "can only change the role, nothing else" do
      patch admin_user_path(target), params: { user: { role: "manager", email_address: "hijack@example.com", verified_at: nil } }
      expect(target.reload).to have_attributes(email_address: target.email_address, role: "manager")
      expect(target).to be_verified
    end

    it "cannot change their own role" do
      get admin_user_path(admin)
      expect(response.body).to include("You can't change your own role.")

      patch admin_user_path(admin), params: { user: { role: "client" } }
      expect_forbidden
      expect(admin.reload.role).to eq("admin")
    end

    it "gets an error for an unknown role" do
      patch admin_user_path(target), params: { user: { role: "superuser" } }
      expect(response).to redirect_to(admin_user_path(target))
      expect(flash[:alert]).to match(/Role/)
      expect(target.reload.role).to eq("client")
    end

    it "answers 404 for an unknown user" do
      get admin_user_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end

    it "can unlock an account (audited)" do
      locked = create(:user, :locked)
      locked.update_columns(failed_login_attempts: 4)

      get admin_user_path(locked)
      expect(response.body).to include("Unlock account")

      patch unlock_admin_user_path(locked)

      expect(response).to redirect_to(admin_user_path(locked))
      expect(locked.reload).not_to be_locked
      expect(locked.failed_login_attempts).to eq(0)
      expect(AuditEvent.where(action: "account.unlocked", user_id: locked.id)).to exist
    end

    it "can sign a user out everywhere (audited)" do
      create_list(:session, 2, user: target)

      delete revoke_sessions_admin_user_path(target)

      expect(response).to redirect_to(admin_user_path(target))
      expect(target.sessions.reload).to be_empty
      expect(AuditEvent.where(action: "sessions.revoked_by_admin", user_id: target.id)).to exist
    end

    it "can resend a pending invitation (audited)" do
      invited = create(:user, :invited)

      expect { post resend_invitation_admin_user_path(invited) }.to have_enqueued_mail(UserMailer, :invitation)

      expect(response).to redirect_to(admin_user_path(invited))
      expect(AuditEvent.where(action: "user.invitation_resent", user_id: invited.id)).to exist
    end

    it "cannot resend once the invitation was accepted" do
      expect { post resend_invitation_admin_user_path(target) }.not_to have_enqueued_mail
      expect_forbidden
    end
  end
end
