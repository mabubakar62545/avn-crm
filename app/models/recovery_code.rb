# app/models/recovery_code.rb
class RecoveryCode < ApplicationRecord
  belongs_to :user
  scope :unused, -> { where(used_at: nil) }

  def self.digest(code)
    key = Rails.application.key_generator.generate_key("recovery_codes")
    OpenSSL::HMAC.hexdigest("SHA256", key, normalize(code))
  end

  def self.normalize(code) = code.to_s.downcase.gsub(/[^a-z0-9]/, "")
end