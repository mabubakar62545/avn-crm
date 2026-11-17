# app/models/sso_sign_in.rb
class SsoSignIn
  Result = Data.define(:user, :error, :created, :accepted_invitation) do
    def initialize(user:, error: nil, created: false, accepted_invitation: false) = super
  end

  STAFF_BY_INVITATION = "Staff accounts are created by invitation. Ask an admin to invite you."

  def initialize(auth)
    @auth = auth
  end

  def call
    if (identity = Identity.find_by(provider: provider, uid: uid))
      identity.update_columns(last_used_at: Time.current, email: email)
      return success(identity.user)
    end

    return failure("Your email address isn't verified with your provider.") unless email_verified?

    if (user = User.find_by(email_address: email))
      return accept_invitation(user) if user.invitation_pending?

      return failure("An account with this email already exists. Sign in with your password, " \
                     "then link single sign-on from your account settings.")
    end

    # Anyone may sign up as a client, except on the company's own domains.
    return failure(STAFF_BY_INVITATION) if User.staff_email?(email)

    Result.new(user: provision_client, created: true)
  end

  private
    attr_reader :auth

    def provider = auth.provider.to_s
    def uid      = auth.uid.to_s
    def email    = auth.info.email.to_s.strip.downcase

    def email_verified?
      [ auth.info["email_verified"], auth.extra&.raw_info&.dig("email_verified") ].any? { |v| v == true || v == "true" }
    end

    # Google has verified the invited address, which is what the emailed link proves.
    def accept_invitation(user)
      return failure("Your invitation has expired. Ask an admin to send a new one.") if user.invitation_expired?

      User.transaction do
        user.update!(verified_at: Time.current)
        user.identities.create!(provider:, uid:, email:, last_used_at: Time.current)
      end
      AuditEvent.record("invitation.accepted", user:, via: provider)
      Result.new(user:, accepted_invitation: true)
    end

    def provision_client
      User.transaction do
        User.new(email_address: email, role: "client", verified_at: Time.current).tap do |user|
          user.assign_unusable_password
          user.save!
          user.identities.create!(provider:, uid:, email:, last_used_at: Time.current)
        end
      end
    end

    def success(user) = Result.new(user:)
    def failure(msg)  = Result.new(user: nil, error: msg)
end
