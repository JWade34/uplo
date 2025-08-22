class EarlyAccessMailer < ApplicationMailer
  def admin_notification(signup)
    @signup = signup
    
    recipients = [ENV['ADMIN_EMAIL_1'], ENV['ADMIN_EMAIL_2']].compact.join(', ')
    
    mail(
      to: recipients,
      subject: "New Uplo Early Access Signup - #{@signup.name}"
    )
  end

  def user_confirmation(signup)
    @signup = signup
    
    mail(
      to: @signup.email,
      subject: "You're on the list! Welcome to Uplo 🎯"
    )
  end
end
