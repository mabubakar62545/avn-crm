module ApplicationHelper
  # SSO providers that are configured (see config/initializers/omniauth.rb).
  def sso_provider_enabled?(provider)
    Rails.configuration.x.sso[provider.to_sym].present?
  end

  # Top-nav link that is highlighted when it points at the current page
  # (or, with `prefix: true`, any page beneath it).
  def nav_link_to(name, path, prefix: false)
    active = prefix ? request.path.start_with?(path) : current_page?(path)
    link_to name, path, class: [ "nav__link", ("is-active" if active) ], aria: { current: ("page" if active) }
  end

  def badge(text, tone = :neutral)
    tag.span text, class: "badge badge--#{tone}"
  end

  def role_badge(user)
    badge user.role.capitalize, { "admin" => :danger, "manager" => :info, "client" => :neutral }.fetch(user.role, :neutral)
  end

  def status_badge(user)
    if user.locked? then badge("Locked", :danger)
    elsif user.invitation_expired? then badge("Invite expired", :danger)
    elsif user.invitation_pending? then badge("Invited", :warning)
    else badge("Active", :success)
    end
  end

  def yes_no_badge(value, yes: "Yes", no: "No")
    value ? badge(yes, :success) : badge(no, :warning)
  end

  # Turns a raw user-agent string into something like "Chrome on macOS".
  def device_label(user_agent)
    ua = user_agent.to_s
    return "Unknown device" if ua.blank?

    browser = case ua
    when /Edg\//          then "Edge"
    when /OPR\/|Opera/    then "Opera"
    when /Firefox\//      then "Firefox"
    when /Chrome\//       then "Chrome"
    when /Safari\//       then "Safari"
    when /curl|Wget/i     then "Command line"
    when /Rails Testing/  then "Test browser"
    else "Browser"
    end

    platform = case ua
    when /iPhone|iPad/    then "iOS"
    when /Android/        then "Android"
    when /Mac OS X/       then "macOS"
    when /Windows/        then "Windows"
    when /Linux/          then "Linux"
    end

    [ browser, platform ].compact.join(" on ")
  end

  def audit_tone(action)
    case action
    when /succeeded|verified|enabled|unlocked|accepted/  then :success
    when /failed|blocked|locked|disabled|revoked/ then :danger
    when /changed|requested|recovery/            then :warning
    else :neutral
    end
  end
end
