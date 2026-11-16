# config/initializers/rack_attack.rb
class Rack::Attack
  # Use Rails' proxy-aware IP (correct behind Kamal/Nginx/a load balancer)
  class Request < ::Rack::Request
    def remote_ip = @remote_ip ||= ActionDispatch::Request.new(env).remote_ip
    def auth_post?(path) = post? && self.path == path
  end

  # 1. General flood protection
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.remote_ip unless req.path.start_with?("/assets")
  end

  # 2. Login: per IP, and per email address (catches distributed attacks)
  throttle("logins/ip", limit: 20, period: 5.minutes) do |req|
    req.remote_ip if req.auth_post?("/session")
  end

  throttle("logins/email", limit: 10, period: 15.minutes) do |req|
    req.params["email_address"].to_s.strip.downcase.presence if req.auth_post?("/session")
  end

  # 3. Endpoints that send email (stops attackers spamming your users/your mail bill)
  throttle("emails/ip", limit: 5, period: 15.minutes) do |req|
    req.remote_ip if req.post? && req.path.in?(%w[/passwords /registration /email_verifications])
  end

  self.throttled_responder = ->(req) {
    retry_after = req.env["rack.attack.match_data"][:period]
    [ 429, { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      [ "Too many requests. Please try again later.\n" ] ]
  }
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |*, payload|
  req = payload[:request]
  Rails.logger.warn "[Rack::Attack] throttled #{req.env['rack.attack.matched']} ip=#{req.remote_ip} path=#{req.path}"
end