class Current < ActiveSupport::CurrentAttributes
  attribute :session, :ip_address, :user_agent, :request_id
  delegate :user, to: :session, allow_nil: true
end
