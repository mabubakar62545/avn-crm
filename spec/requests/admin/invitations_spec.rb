require "rails_helper"

RSpec.describe "Admin: invitations" do
  let(:admin) { create(:user, :admin) }

  def invite(email: "jane@avn.example", role: "manager")
    post admin_invitations_path, params: { invitation: { email_address: email, role: } }
  end

  it "requires sign-in" do
    expect { invite }.not_to change(User, :count)
    expect(response).to redirect_to(new_session_path)
  end

  it "lets admins invite an employee" do
    sign_in_as(admin)

    expect { invite }.to change(User, :count).by(1).and have_enqueued_mail(UserMailer, :invitation)

    user = User.find_by!(email_address: "jane@avn.example")
    expect(response).to redirect_to(admin_user_path(user))
    expect(user).to have_attributes(role: "manager", invited_by: admin)
    expect(user).to be_invitation_pending
    expect(AuditEvent.where(action: "user.invited", user_id: user.id, actor_id: admin.id)).to exist
    expect(AuditEvent.where(action: "user.registered", user_id: user.id)).not_to exist
  end

  it "refuses managers and clients" do
    [ create(:user, :manager), create(:user, :client) ].each do |user|
      sign_in_as(user)
      expect { invite(role: "admin") }.not_to change(User, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  it "refuses an existing email or an unknown role" do
    sign_in_as(admin)
    taken = create(:user)

    expect { invite(email: taken.email_address) }.not_to change(User, :count)
    expect(response).to redirect_to(admin_users_path)
    expect(flash[:alert]).to match(/already been taken/)

    expect { invite(email: "x@avn.example", role: "superuser") }.not_to change(User, :count)
    expect(response).to redirect_to(admin_users_path)
  end

  it "answers 400 when the invitation params are missing" do
    sign_in_as(admin)
    post admin_invitations_path
    expect(response).to have_http_status(:bad_request)
  end

  it "shows the invite form only to admins" do
    sign_in_as(admin)
    get admin_users_path
    expect(response.parsed_body.css("form#invite_user_form")).to be_present

    sign_in_as(create(:user, :manager))
    get admin_users_path
    expect(response.parsed_body.css("form#invite_user_form")).to be_empty
  end
end
