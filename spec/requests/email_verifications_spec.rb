require "rails_helper"

RSpec.describe "Email verification" do
  let(:user) { create(:user, :unverified) }
  let(:token) { user.generate_token_for(:email_verification) }

  it "GET new renders the resend form" do
    get new_email_verification_path
    expect(response).to have_http_status(:ok)
  end

  describe "POST /email_verifications" do
    it "resends the link to an unverified user" do
      expect { post email_verifications_path, params: { email_address: user.email_address } }
        .to have_enqueued_mail(UserMailer, :email_verification).with(user)
      expect(response).to redirect_to(new_session_path)
    end

    it "sends nothing to a verified or unknown address, with the same answer" do
      verified = create(:user)
      expect { post email_verifications_path, params: { email_address: verified.email_address } }.not_to have_enqueued_mail
      expect(response).to redirect_to(new_session_path)

      expect { post email_verifications_path, params: { email_address: "nobody@example.com" } }.not_to have_enqueued_mail
      expect(response).to redirect_to(new_session_path)
    end

    it "is rate-limited", rack_attack: false do
      5.times { post email_verifications_path, params: { email_address: "x@example.com" } }

      expect { post email_verifications_path, params: { email_address: user.email_address } }.not_to have_enqueued_mail
      expect(response).to redirect_to(new_email_verification_path)
      expect(flash[:alert]).to eq("Try again later.")
    end
  end

  it "GET show asks for confirmation instead of verifying (safe from link scanners)" do
    get email_verification_path(token)
    expect(response).to have_http_status(:ok)
    expect(user.reload).not_to be_verified
  end

  describe "PATCH /email_verifications/:token" do
    it "verifies the email" do
      patch email_verification_path(token)
      expect(response).to redirect_to(new_session_path)
      expect(user.reload).to be_verified
    end

    it "is harmless for an already verified user" do
      verified = create(:user, verified_at: 3.days.ago)
      patch email_verification_path(verified.generate_token_for(:email_verification))
      expect(response).to redirect_to(new_session_path)
      expect(verified.reload.verified_at).to be_within(1.second).of(3.days.ago)
    end
  end

  it "rejects an invalid or expired token" do
    get email_verification_path("bogus")
    expect(response).to redirect_to(new_email_verification_path)

    stale = token
    travel 2.days + 1.minute
    patch email_verification_path(stale)
    expect(response).to redirect_to(new_email_verification_path)
    expect(user.reload).not_to be_verified
  end
end
