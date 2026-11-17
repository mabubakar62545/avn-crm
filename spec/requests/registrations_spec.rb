require "rails_helper"

RSpec.describe "Registrations" do
  def register(email: "new@example.com", password: "a-long-secret-123", confirmation: password, **extra)
    post registration_path, params: { user: { email_address: email, password:, password_confirmation: confirmation, **extra } }
  end

  it "GET new renders the sign-up form with Google" do
    get new_registration_path
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.css("form[action='/auth/google'] button").text).to eq("Sign up with Google")
  end

  it "creates an unverified client and emails a confirmation link" do
    expect { register }.to change(User, :count).by(1).and have_enqueued_mail(UserMailer, :email_verification)

    user = User.find_by!(email_address: "new@example.com")
    expect(user).not_to be_verified
    expect(user.role).to eq("client")
    expect(user.sessions).to be_empty
    expect(response).to redirect_to(new_session_path)
  end

  it "ignores a role sent in the form (no privilege escalation)" do
    register(role: "admin")
    expect(User.find_by!(email_address: "new@example.com").role).to eq("client")
  end

  it "does not reveal an existing email and notifies its owner instead" do
    existing = create(:user)

    expect { register(email: existing.email_address.upcase) }
      .to not_change(User, :count).and have_enqueued_mail(UserMailer, :already_registered).with(existing)
    expect(response).to redirect_to(new_session_path)
    expect(flash[:notice]).to eq("Check your email to confirm your account.")
  end

  it "re-renders the form with errors for invalid data" do
    expect { register(email: "bad", password: "short") }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.css("#form_errors")).to be_present
  end

  it "refuses staff-domain emails (staff join by invitation)" do
    expect { register(email: "jane@avn.example") }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Staff accounts are created by invitation")
  end

  it "answers 400 when the user params are missing" do
    post registration_path
    expect(response).to have_http_status(:bad_request)
  end

  it "is rate-limited", rack_attack: false do
    10.times { |i| register(email: "bad#{i}", password: "short") }

    expect { register }.not_to change(User, :count)
    expect(response).to redirect_to(new_registration_path)
    expect(flash[:alert]).to eq("Too many attempts. Try again later.")
  end
end
