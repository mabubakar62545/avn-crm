# Company email domains. People on these domains can't sign up as clients
# (password or Google); their accounts come from an admin invitation or the console.
#
# Set in credentials (bin/rails credentials:edit):
#   staff_domains:
#     - yourcompany.com
# or with STAFF_DOMAINS=yourcompany.com,other.com. Environments may set config.x.staff_domains (tests do).
domains = Rails.configuration.x.staff_domains.presence ||
          Rails.application.credentials.staff_domains ||
          ENV["STAFF_DOMAINS"].to_s.split(",")
Rails.configuration.x.staff_domains = Array(domains).map { |d| d.to_s.strip.downcase }.compact_blank.freeze
