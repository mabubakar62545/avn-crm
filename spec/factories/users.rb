FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "person#{n}@example.com" }
    password { "TestPassword123!" }
    role { "client" }
    verified_at { 1.week.ago }

    trait(:client)  { role { "client" } }
    trait(:manager) { role { "manager" } }
    trait(:admin)   { role { "admin" } }

    trait(:unverified) { verified_at { nil } }

    trait :locked do
      after(:create) { |user| user.update_columns(locked_until: 1.hour.from_now) }
    end

    # Signed up with Google: has a random password the user never chose.
    trait :sso_only do
      after(:build) { |user| user.assign_unusable_password }
    end

    trait :invited do
      verified_at { nil }
      invited_at { Time.current }
      after(:build) { |user| user.assign_unusable_password }
    end

    trait :with_two_factor do
      after(:create) { |user| user.enable_otp!(ROTP::Base32.random) }
    end
  end
end
