require "rails_helper"

RSpec.describe "Rack::Attack throttling" do
  def expect_throttled(period:)
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["Retry-After"]).to eq(period.to_i.to_s)
    expect(response.body).to eq("Too many requests. Please try again later.\n")
  end

  it "throttles sign-in attempts per email address, however it is written" do
    10.times { post session_path, params: { email_address: "Victim@Example.com ", password: "x" } }
    post session_path, params: { email_address: "victim@example.com", password: "x" }
    expect_throttled(period: 15.minutes)
  end

  it "throttles sign-in attempts per IP across many emails" do
    20.times { |i| post session_path, params: { email_address: "user#{i}@example.com", password: "x" } }
    post session_path, params: { email_address: "fresh@example.com", password: "x" }
    expect_throttled(period: 5.minutes)
  end

  it "does not throttle sign-ins by email when no email is given" do
    11.times { post session_path }
    expect(response).not_to have_http_status(:too_many_requests)
  end

  { "/passwords" => { email_address: "a@example.com" },
    "/registration" => { user: { email_address: "a@example.com" } },
    "/email_verifications" => { email_address: "a@example.com" } }.each do |path, params|
    it "throttles email-sending POST #{path} per IP" do
      5.times { post path, params: }
      post(path, params:)
      expect_throttled(period: 15.minutes)
    end
  end

  it "applies general flood protection per IP" do
    300.times { get new_session_path }
    get new_session_path
    expect_throttled(period: 5.minutes)
  end

  it "never throttles assets" do
    301.times { get "/assets/missing.css" }
    expect(response).not_to have_http_status(:too_many_requests)
  end

  it "logs throttled requests" do
    allow(Rails.logger).to receive(:warn).and_call_original
    6.times { post passwords_path, params: { email_address: "a@example.com" } }
    expect(Rails.logger).to have_received(:warn).with(a_string_including("[Rack::Attack] throttled emails/ip", "path=/passwords"))
  end
end
