# app/models/session.rb
class Session < ApplicationRecord
  IDLE_TIMEOUT     = 2.hours
  ABSOLUTE_TIMEOUT = 2.weeks
  ACTIVITY_THROTTLE = 1.minute

  belongs_to :user

  scope :expired, -> {
    where(last_active_at: ...IDLE_TIMEOUT.ago).or(where(created_at: ...ABSOLUTE_TIMEOUT.ago))
  }

  def expired?
    last_active_at < IDLE_TIMEOUT.ago || created_at < ABSOLUTE_TIMEOUT.ago
  end

  def record_activity!
    update_column(:last_active_at, Time.current) if last_active_at < ACTIVITY_THROTTLE.ago
  end
end