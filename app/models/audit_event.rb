# app/models/audit_event.rb
class AuditEvent < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :user, optional: true

  validates :action, presence: true
  scope :recent, -> { order(created_at: :desc) }

  def readonly? = persisted?

  def self.record(action, user: nil, actor: Current.user, **metadata)
    event = create!(
      action:, user:, actor:, metadata:,
      user_email: user&.email_address,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent&.truncate(255),
      request_id: Current.request_id
    )
    Rails.logger.info({ audit: action, user_id: user&.id, actor_id: actor&.id, ip: Current.ip_address, **metadata }.to_json)
    event
  rescue => e
    Rails.error.report(e, context: { audit_action: action })
    nil
  end
end