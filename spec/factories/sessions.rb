FactoryBot.define do
  factory :session do
    user
    ip_address { "127.0.0.1" }
    user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Version/17.0 Safari/605.1.15" }
  end
end
