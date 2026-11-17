require "rails_helper"

RSpec.describe "Accepting an invitation" do
  let(:admin) { create(:user, :admin) }
  let!(:invited) { User.invite!(email_address: "jane@avn.example", role: "manager", invited_by: admin) }
  let(:token) { invited.generate_token_for(:invitation) }

  def accept(password: "a-long-secret-123", confirmation: password, with: token)
    patch invitation_path(with), params: { password:, password_confirmation: confirmation }
  end

  it "the invited user can't sign in before accepting" do
    post session_path, params: { email_address: invited.email_address, password: "a-long-secret-123" }
    expect(response).to redirect_to(new_session_path)
  end

  it "shows a password form and Google" do
    get invitation_path(token)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.css("form#accept_invitation_form")).to be_present
    expect(response.parsed_body.css("form[action='/auth/google']")).to be_present
  end

  it "accepting with a password verifies the account, signs in and audits" do
    expect { accept }.to change(invited.sessions, :count).by(1)

    expect(response).to redirect_to(root_url)
    expect(flash[:notice]).to match(/Your account is ready/)
    invited.reload
    expect(invited).to be_verified
    expect(invited).to be_password_set
    expect(invited).not_to be_invitation_pending
    expect(AuditEvent.find_by!(action: "invitation.accepted", user_id: invited.id).metadata).to eq("via" => "password")
    expect(AuditEvent.where(action: "login.succeeded", user_id: invited.id).sole.metadata["via"]).to eq("invitation")
  end

  it "the link stops working once accepted" do
    old = token
    accept
    delete session_path

    get invitation_path(old)
    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to match(/invalid or has expired/)
  end

  it "resending invalidates the old link" do
    old = token
    travel 1.second
    invited.resend_invitation!

    get invitation_path(old)
    expect(response).to redirect_to(new_session_path)
  end

  it "the link expires after a week" do
    old = token
    travel User::INVITATION_TTL + 1.minute
    accept(with: old)
    expect(response).to redirect_to(new_session_path)
    expect(invited.reload).not_to be_verified
  end

  it "rejects a forged token" do
    accept(with: "bogus")
    expect(response).to redirect_to(new_session_path)
  end

  it "re-renders the form for mismatched or blank passwords" do
    accept(confirmation: "something-else-1")
    expect(response).to have_http_status(:unprocessable_content)
    expect(flash[:alert]).to match(/doesn't match/)

    accept(password: "")
    expect(response).to have_http_status(:unprocessable_content)
    expect(flash[:alert]).to match(/can't be blank/)

    patch invitation_path(token)
    expect(response).to have_http_status(:unprocessable_content)
    expect(invited.reload).not_to be_verified
  end

  it "is rate-limited" do
    10.times { accept(password: "") }
    accept
    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to eq("Try again later.")
    expect(invited.reload).not_to be_verified
  end
end
