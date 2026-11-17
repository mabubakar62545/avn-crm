require "rails_helper"

RSpec.describe User do
  subject(:user) { build(:user) }

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:recovery_codes).dependent(:delete_all) }
    it { is_expected.to have_many(:identities).dependent(:destroy) }
    it { is_expected.to belong_to(:invited_by).class_name("User").optional }
  end

  describe "email normalization" do
    it "strips and downcases the email address" do
      expect(described_class.new(email_address: " DOWNCASED@EXAMPLE.COM ").email_address).to eq("downcased@example.com")
    end
  end

  describe "validations" do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_length_of(:email_address).is_at_most(254) }

    it "rejects a malformed email address" do
      user.email_address = "not-an-email"
      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to include("is invalid")
    end

    it "rejects a duplicate email address regardless of case" do
      create(:user, email_address: "taken@example.com")
      user.email_address = "TAKEN@example.com"
      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to include("has already been taken")
    end

    it "requires a password of at least 12 characters" do
      user.password = user.password_confirmation = "short-pw1"
      expect(user).not_to be_valid
      expect(user.errors[:password].first).to match(/too short/)
    end

    it "requires the password confirmation to match" do
      user.password_confirmation = "something-else-entirely"
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to be_present
    end

    it "rejects a password that contains the email's local part" do
      user.email_address = "jane.doe@example.com"
      user.password = "my-JANE.DOE-secret"
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't contain your email")
    end

    it "rejects any password when there is no email to compare against" do
      user.email_address = nil
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't contain your email")
    end

    it "does not apply the email check to a generated password (short email names)" do
      sso = build(:user, email_address: "a@gmail.com")
      allow(SecureRandom).to receive(:base58).and_return("contains-a-for-sure-aaaaaaaaaaaa")
      sso.assign_unusable_password
      expect(sso).to be_valid
    end

    it "skips the password checks when the password is not being changed" do
      saved = create(:user)
      found = described_class.find(saved.id)
      expect(found.password).to be_nil
      expect(found.update(role: "manager")).to be(true)
    end

    it "rejects an unknown role without raising" do
      user.role = "superuser"
      expect(user).not_to be_valid
      expect(user.errors[:role]).to be_present
    end

    it "defaults the role to client" do
      expect(described_class.new.role).to eq("client")
    end
  end

  describe "#at_least?" do
    it "ranks client < manager < admin" do
      client, manager, admin = build(:user, :client), build(:user, :manager), build(:user, :admin)

      expect(admin.at_least?(:manager)).to be(true)
      expect(admin.at_least?("admin")).to be(true)
      expect(manager.at_least?(:manager)).to be(true)
      expect(manager.at_least?(:admin)).to be(false)
      expect(client.at_least?(:client)).to be(true)
      expect(client.at_least?(:manager)).to be(false)
    end
  end

  describe ".staff_email?" do
    it "is true for configured company domains, ignoring case and whitespace" do
      expect(described_class.staff_email?("jane@avn.example")).to be(true)
      expect(described_class.staff_email?("  Jane@AVN.Example ")).to be(true)
    end

    # A value without "@" is read as a bare domain. Such values never pass the email
    # format validation, so this only matters for callers that check before validating.
    it "treats a bare domain as that domain" do
      expect(described_class.staff_email?("avn.example")).to be(true)
    end

    it "is false for other domains, subdomains, or blank values" do
      expect(described_class.staff_email?("jane@gmail.com")).to be(false)
      expect(described_class.staff_email?("jane@sub.avn.example")).to be(false)
      expect(described_class.staff_email?("")).to be(false)
      expect(described_class.staff_email?(nil)).to be(false)
    end
  end

  describe "password bookkeeping" do
    it "stamps password_set_at when a real password is chosen" do
      expect(create(:user).password_set_at).to be_present
      expect(create(:user)).to be_password_set
    end

    it "does not count a generated (unusable) password as set" do
      sso = create(:user, :sso_only)
      expect(sso.password_set_at).to be_nil
      expect(sso).not_to be_password_set
    end

    it "stamps password_set_at once the user later picks a password" do
      sso = create(:user, :sso_only)
      sso.update!(password: "a-brand-new-passphrase")
      expect(sso).to be_password_set
    end

    it "clears any lockout when the password changes" do
      saved = create(:user)
      saved.update_columns(locked_until: 1.hour.from_now, failed_login_attempts: 7)

      saved.update!(password: "a-brand-new-passphrase")

      expect(saved.reload.locked_until).to be_nil
      expect(saved.failed_login_attempts).to eq(0)
    end
  end

  describe "revoking sessions on password change" do
    let!(:saved) { create(:user) }
    let!(:current) { saved.sessions.create! }
    let!(:other) { saved.sessions.create! }

    it "keeps the current session and signs out the rest" do
      Current.session = current
      saved.update!(password: "a-brand-new-passphrase")
      expect(saved.sessions.reload).to contain_exactly(current)
    end

    it "signs out every session when there is no current one (e.g. password reset)" do
      saved.update!(password: "a-brand-new-passphrase")
      expect(saved.sessions.reload).to be_empty
    end

    it "leaves sessions alone when something else changes" do
      saved.update!(role: "manager")
      expect(saved.sessions.reload).to contain_exactly(current, other)
    end
  end

  describe "audit trail" do
    def actions_for(record) = AuditEvent.where(user_id: record.id).pluck(:action)

    it "records self-registration" do
      expect(actions_for(create(:user))).to eq([ "user.registered" ])
    end

    it "does not record registration for invited users" do
      expect(actions_for(create(:user, :invited))).not_to include("user.registered")
    end

    it "records password changes" do
      saved = create(:user)
      saved.update!(password: "a-brand-new-passphrase")
      expect(actions_for(saved)).to include("password.changed")
    end

    it "records email verification, but not un-verification" do
      saved = create(:user, :unverified)
      saved.verify!
      expect(actions_for(saved)).to include("email.verified")

      saved.update!(verified_at: nil)
      expect(actions_for(saved).count("email.verified")).to eq(1)
    end

    it "records role changes with the before and after role" do
      saved = create(:user)
      saved.update!(role: "admin")
      event = AuditEvent.find_by!(user_id: saved.id, action: "role.changed")
      expect(event.metadata).to eq("from" => "client", "to" => "admin")
    end

    it "records MFA being enabled and disabled" do
      saved = create(:user)
      saved.enable_otp!(ROTP::Base32.random)
      saved.disable_otp!
      expect(actions_for(saved)).to include("mfa.enabled", "mfa.disabled")
    end

    it "records nothing for unrelated updates" do
      saved = create(:user)
      expect { saved.update!(failed_login_attempts: 2) }.not_to change(AuditEvent, :count)
    end
  end

  describe "tokens" do
    let(:saved) { create(:user, :unverified) }

    it "issues an email verification token that resolves to the user for 2 days" do
      token = saved.generate_token_for(:email_verification)
      expect(described_class.find_by_token_for(:email_verification, token)).to eq(saved)

      travel 2.days + 1.minute
      expect(described_class.find_by_token_for(:email_verification, token)).to be_nil
    end

    it "invalidates the verification token if the email changes" do
      token = saved.generate_token_for(:email_verification)
      saved.update!(email_address: "changed@example.com")
      expect(described_class.find_by_token_for(:email_verification, token)).to be_nil
    end

    it "does not accept an email verification token as an invitation token" do
      token = saved.generate_token_for(:email_verification)
      expect(described_class.find_by_token_for(:invitation, token)).to be_nil
    end

    describe "invitation token" do
      let(:invited) { create(:user, :invited) }
      let!(:token) { invited.generate_token_for(:invitation) }

      def resolve = described_class.find_by_token_for(:invitation, token)

      it("resolves to the invited user") { expect(resolve).to eq(invited) }

      it "expires after the invitation TTL" do
        travel described_class::INVITATION_TTL + 1.minute
        expect(resolve).to be_nil
      end

      it "dies when the invitation is resent" do
        travel 1.second
        invited.resend_invitation!
        expect(resolve).to be_nil
      end

      it "dies once the user is verified" do
        invited.verify!
        expect(resolve).to be_nil
      end

      it "dies once a password is set" do
        invited.update!(password: "a-brand-new-passphrase")
        expect(resolve).to be_nil
      end
    end

    it "binds an invitation token for a never-invited user to their password, too" do
      regular = create(:user)
      token = regular.generate_token_for(:invitation)
      travel 1.second # the token compares timestamps at one-second resolution
      regular.update!(password: "a-brand-new-passphrase")
      expect(described_class.find_by_token_for(:invitation, token)).to be_nil
    end

    it "issues a password reset token that dies once the password changes" do
      token = saved.password_reset_token
      expect(described_class.find_by_password_reset_token(token)).to eq(saved)

      saved.update!(password: "a-brand-new-passphrase")
      expect(described_class.find_by_password_reset_token(token)).to be_nil
    end
  end

  describe ".invite!" do
    let(:admin) { create(:user, :admin) }

    it "creates a pending, unverified account with no usable password and emails a link" do
      invited = nil
      expect {
        invited = described_class.invite!(email_address: "jane@avn.example", role: "manager", invited_by: admin)
      }.to have_enqueued_mail(UserMailer, :invitation)

      expect(invited).to be_persisted
      expect(invited).to have_attributes(role: "manager", invited_by: admin, verified_at: nil)
      expect(invited).to be_invitation_pending
      expect(invited).not_to be_password_set
    end

    it "records who sent the invitation" do
      invited = described_class.invite!(email_address: "jane@avn.example", role: "manager", invited_by: admin)
      event = AuditEvent.find_by!(action: "user.invited", user_id: invited.id)
      expect(event.actor).to eq(admin)
      expect(event.metadata).to eq("role" => "manager", "via" => "admin")
    end

    it "records console invitations without an actor" do
      invited = described_class.invite!(email_address: "jane@avn.example", role: "admin")
      event = AuditEvent.find_by!(action: "user.invited", user_id: invited.id)
      expect(event.actor).to be_nil
      expect(event.metadata["via"]).to eq("console")
    end

    it "raises for an existing email or an unknown role" do
      create(:user, email_address: "taken@example.com")
      expect { described_class.invite!(email_address: "taken@example.com", role: "manager") }.to raise_error(ActiveRecord::RecordInvalid)
      expect { described_class.invite!(email_address: "new@example.com", role: "root") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "invitation state" do
    it "is pending only while invited and unverified" do
      expect(build(:user)).not_to be_invitation_pending
      expect(build(:user, :invited)).to be_invitation_pending
      expect(build(:user, :invited, verified_at: Time.current)).not_to be_invitation_pending
    end

    it "expires once the TTL has passed on a pending invitation" do
      expect(build(:user, :invited)).not_to be_invitation_expired
      expect(build(:user, :invited, invited_at: 8.days.ago)).to be_invitation_expired
      expect(build(:user, invited_at: 8.days.ago)).not_to be_invitation_expired
    end

    it "#resend_invitation! bumps invited_at and emails a fresh link" do
      invited = create(:user, :invited, invited_at: 3.days.ago)
      expect { invited.resend_invitation! }.to have_enqueued_mail(UserMailer, :invitation)
      expect(invited.invited_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "#accept_invitation" do
    let(:invited) { create(:user, :invited) }

    it "sets the password and verifies the account" do
      expect(invited.accept_invitation(password: "a-long-secret-123", password_confirmation: "a-long-secret-123")).to be(true)
      expect(invited).to be_verified
      expect(invited).to be_password_set
      expect(invited.authenticate("a-long-secret-123")).to eq(invited)
    end

    it "refuses a blank password" do
      expect(invited.accept_invitation(password: "", password_confirmation: "")).to be(false)
      expect(invited.errors[:password]).to include("can't be blank")
      expect(invited.reload).not_to be_verified
    end

    it "refuses a mismatched confirmation" do
      expect(invited.accept_invitation(password: "a-long-secret-123", password_confirmation: "nope-nope-nope")).to be(false)
      expect(invited.reload).not_to be_verified
    end
  end

  describe "#can_unlink_identity?" do
    it "is true when the user has a password" do
      expect(create(:user)).to be_can_unlink_identity
    end

    it "is false for an SSO-only user with a single identity" do
      sso = create(:user, :sso_only)
      create(:identity, user: sso)
      expect(sso).not_to be_can_unlink_identity
    end

    it "is true for an SSO-only user with more than one identity" do
      sso = create(:user, :sso_only)
      create(:identity, user: sso, provider: "google")
      create(:identity, user: sso, provider: "microsoft")
      expect(sso).to be_can_unlink_identity
    end
  end

  describe "verification" do
    it "#verified? reflects verified_at" do
      expect(build(:user)).to be_verified
      expect(build(:user, :unverified)).not_to be_verified
    end

    it "#verify! stamps verified_at" do
      saved = create(:user, :unverified)
      saved.verify!
      expect(saved.reload).to be_verified
    end
  end

  describe "lockout" do
    let(:saved) { create(:user) }

    it "#locked? is true only while locked_until is in the future" do
      expect(saved).not_to be_locked
      saved.locked_until = 1.minute.ago
      expect(saved).not_to be_locked
      saved.locked_until = 1.minute.from_now
      expect(saved).to be_locked
    end

    it "#register_failed_login! counts each failure" do
      expect { saved.register_failed_login! }.to change { saved.reload.failed_login_attempts }.from(0).to(1)
    end

    it "locks the account after too many failures, emails the user and audits it" do
      saved.update_columns(failed_login_attempts: described_class::MAX_FAILED_LOGINS - 1)

      expect { saved.register_failed_login! }.to have_enqueued_mail(UserMailer, :account_locked)

      expect(saved).to be_locked
      expect(saved.locked_until).to be_within(1.second).of(described_class::LOCKOUT_DURATION.from_now)
      expect(saved.failed_login_attempts).to eq(0)
      expect(AuditEvent.exists?(action: "account.locked", user_id: saved.id)).to be(true)
    end

    it "does not count failures while already locked" do
      saved.update_columns(locked_until: 1.hour.from_now, failed_login_attempts: 3)
      expect { saved.register_failed_login! }.not_to change { saved.reload.failed_login_attempts }
    end

    it "unlocks automatically once the lockout expires" do
      saved.update_columns(locked_until: described_class::LOCKOUT_DURATION.from_now)
      travel described_class::LOCKOUT_DURATION + 1.second
      expect(saved).not_to be_locked
    end

    it "#reset_failed_logins! zeroes the counter" do
      saved.update_columns(failed_login_attempts: 4)
      saved.reset_failed_logins!
      expect(saved.reload.failed_login_attempts).to eq(0)
    end

    it "#reset_failed_logins! skips the write when there is nothing to reset" do
      expect(saved).not_to receive(:update_columns)
      saved.reset_failed_logins!
    end
  end

  describe "two-factor authentication" do
    let(:saved) { create(:user) }
    let(:secret) { ROTP::Base32.random }

    it "builds a provisioning URI with the issuer and email" do
      uri = saved.otp_provisioning_uri(secret)
      expect(uri).to start_with("otpauth://totp/")
      expect(uri).to include("secret=#{secret}", "issuer=AVN%20CRM", ERB::Util.url_encode(saved.email_address))
    end

    it "is off until enabled" do
      expect(saved).not_to be_otp_enabled
    end

    describe "#enable_otp!" do
      it "stores the secret, turns 2FA on, and returns single-use recovery codes" do
        codes = saved.enable_otp!(secret)

        expect(saved).to be_otp_enabled
        expect(saved.otp_secret).to eq(secret)
        expect(codes.size).to eq(described_class::RECOVERY_CODE_COUNT)
        expect(codes).to all(match(/\A[a-z0-9]{5}-[a-z0-9]{5}\z/))
        expect(saved.recovery_codes.count).to eq(described_class::RECOVERY_CODE_COUNT)
      end

      it "encrypts the secret at rest" do
        saved.enable_otp!(secret)
        raw = described_class.connection.select_value("SELECT otp_secret FROM users WHERE id = #{saved.id}")
        expect(raw).not_to include(secret)
      end
    end

    describe "#verify_otp" do
      before { saved.enable_otp!(secret) }

      it "accepts the current code once and rejects reuse" do
        code = ROTP::TOTP.new(secret).now
        expect(saved.verify_otp(code)).to be(true)
        expect(saved.verify_otp(code)).to be(false)
      end

      it "ignores whitespace in the code" do
        code = ROTP::TOTP.new(secret).now
        expect(saved.verify_otp("#{code[0, 3]} #{code[3, 3]}")).to be(true)
      end

      it "accepts a code from the previous time step (clock drift)" do
        code = ROTP::TOTP.new(secret).at(30.seconds.ago)
        expect(saved.verify_otp(code)).to be(true)
      end

      it "rejects a code outside the drift window" do
        expect(saved.verify_otp(ROTP::TOTP.new(secret).at(5.minutes.ago))).to be(false)
        expect(saved.verify_otp(ROTP::TOTP.new(secret).at(5.minutes.from_now))).to be(false)
      end

      it "rejects a blank code" do
        expect(saved.verify_otp("")).to be(false)
        expect(saved.verify_otp(nil)).to be(false)
      end

      it "rejects when there is no secret" do
        expect(create(:user).verify_otp("123456")).to be(false)
      end

      it "can check a code against a pending secret before 2FA is on" do
        other = create(:user)
        pending_secret = ROTP::Base32.random
        expect(other.verify_otp(ROTP::TOTP.new(pending_secret).now, secret: pending_secret)).to be(true)
      end
    end

    describe "recovery codes" do
      let!(:codes) { saved.enable_otp!(secret) }

      it "are stored hashed, never in plaintext" do
        expect(saved.recovery_codes.pluck(:code_digest)).not_to include(*codes)
        expect(saved.recovery_codes.pluck(:code_digest)).to include(RecoveryCode.digest(codes.first))
      end

      it "can each be used exactly once" do
        expect(saved.consume_recovery_code(codes.first)).to be(true)
        expect(saved.consume_recovery_code(codes.first)).to be(false)
        expect(saved.recovery_codes.unused.count).to eq(described_class::RECOVERY_CODE_COUNT - 1)
      end

      it "are accepted regardless of case and dashes" do
        expect(saved.consume_recovery_code(codes.first.upcase.delete("-"))).to be(true)
      end

      it "reject blank, unknown, or another user's codes" do
        other_codes = create(:user).enable_otp!(ROTP::Base32.random)

        expect(saved.consume_recovery_code("")).to be(false)
        expect(saved.consume_recovery_code("aaaaa-bbbbb")).to be(false)
        expect(saved.consume_recovery_code(other_codes.first)).to be(false)
      end

      it "are replaced when regenerated" do
        fresh = saved.regenerate_recovery_codes!
        expect(saved.consume_recovery_code(codes.first)).to be(false)
        expect(saved.consume_recovery_code(fresh.first)).to be(true)
        expect(saved.recovery_codes.count).to eq(described_class::RECOVERY_CODE_COUNT)
      end
    end

    describe "#disable_otp!" do
      it "removes the secret, the last-used marker and every recovery code" do
        saved.enable_otp!(secret)
        saved.verify_otp(ROTP::TOTP.new(secret).now)

        saved.disable_otp!

        expect(saved.reload).to have_attributes(otp_secret: nil, otp_enabled_at: nil, otp_last_used_at: nil)
        expect(saved.recovery_codes).to be_empty
      end
    end
  end
end
