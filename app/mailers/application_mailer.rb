class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "AVN CRM <no-reply@avn-crm.local>")
  layout "mailer"
end
