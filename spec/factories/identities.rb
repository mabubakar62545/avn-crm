FactoryBot.define do
  factory :identity do
    user
    provider { "google" }
    sequence(:uid) { |n| "google-uid-#{n}" }
    email { user.email_address }
  end
end
