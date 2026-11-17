FactoryBot.define do
  factory :audit_event do
    action { "login.succeeded" }
    user
  end
end
