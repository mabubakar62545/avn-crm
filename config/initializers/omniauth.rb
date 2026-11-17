# config/initializers/omniauth.rb
app_url = ENV.fetch("APP_URL", "http://localhost:3000")
# SSO settings come from credentials, unless an environment sets config.x.sso (tests do).
sso = Rails.configuration.x.sso.presence || Rails.application.credentials.sso || {}
Rails.configuration.x.sso = sso

Rails.application.config.middleware.use OmniAuth::Builder do
  if sso[:google]
    provider :openid_connect,
      name: :google,
      issuer: "https://accounts.google.com",
      discovery: true,
      scope: %i[openid email profile],
      response_type: :code,
      pkce: true,
      client_options: {
        identifier:   sso[:google][:client_id],
        secret:       sso[:google][:client_secret],
        redirect_uri: "#{app_url}/auth/google/callback"
      }
  end
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.on_failure = proc { |env| OmniAuth::FailureEndpoint.new(env).redirect_to_failure }
