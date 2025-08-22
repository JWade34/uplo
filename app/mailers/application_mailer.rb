class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('FROM_EMAIL', 'noreply@getuplo.com')
  layout "mailer"
end
