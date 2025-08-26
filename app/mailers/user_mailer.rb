class UserMailer < ApplicationMailer
  # Email 1: Instant Welcome (0 minutes after signup)
  def welcome_email(user)
    @user = user
    @cta_url = new_photo_url
    
    # Add Resend tracking headers
    headers['X-Entity-Ref-ID'] = "welcome-#{user.id}-#{Time.current.to_i}"
    
    mail(
      to: @user.email_address,
      subject: "Welcome to Uplo! Let's get your first post ready 🚀"
    )
  end
  
  # Email 2: Getting Started Tips (24 hours after signup)
  def getting_started_tips(user)
    @user = user
    @upload_url = new_photo_url
    @pricing_url = pricing_url
    
    # Add Resend tracking headers
    headers['X-Entity-Ref-ID'] = "tips-#{user.id}-#{Time.current.to_i}"
    
    mail(
      to: @user.email_address,
      subject: "Ready to 10x your social media results? Here's how..."
    )
  end
  
  # Email 3: Common Mistakes (72 hours after signup)
  def common_mistakes(user)
    @user = user
    @profile_url = onboarding_profile_url
    @upload_url = new_photo_url
    
    # Add Resend tracking headers
    headers['X-Entity-Ref-ID'] = "mistakes-#{user.id}-#{Time.current.to_i}"
    
    mail(
      to: @user.email_address,
      subject: "The #1 mistake that kills trainer social media growth"
    )
  end
  
  # Email 4: Success Stories + Upgrade (7 days after signup)
  def success_stories(user)
    @user = user
    @pricing_url = pricing_url
    @upgrade_url = pricing_url(utm_source: 'email', utm_medium: 'success_stories', utm_campaign: 'day_7')
    
    # Add Resend tracking headers
    headers['X-Entity-Ref-ID'] = "success-#{user.id}-#{Time.current.to_i}"
    
    mail(
      to: @user.email_address,
      subject: "How trainers are booking 5+ clients per month with simple posts"
    )
  end
  
  # Email 5: Final Conversion Push (14 days after signup)
  def final_conversion(user)
    @user = user
    @photos_uploaded = user.photos.count
    @upgrade_url = pricing_url(utm_source: 'email', utm_medium: 'final_conversion', utm_campaign: 'day_14')
    @support_email = 'support@getuplo.com'
    
    # Add Resend tracking headers
    headers['X-Entity-Ref-ID'] = "final-#{user.id}-#{Time.current.to_i}"
    
    mail(
      to: @user.email_address,
      subject: "Last chance: Keep the momentum going 💪"
    )
  end
  
  private
  
  def new_photo_url
    Rails.application.routes.url_helpers.new_photo_url(
      host: Rails.application.config.action_mailer.default_url_options[:host],
      protocol: Rails.application.config.action_mailer.default_url_options[:protocol]
    )
  end
  
  def pricing_url(params = {})
    base_params = {
      host: Rails.application.config.action_mailer.default_url_options[:host],
      protocol: Rails.application.config.action_mailer.default_url_options[:protocol]
    }
    
    Rails.application.routes.url_helpers.pricing_url(base_params.merge(params))
  end
  
  def onboarding_profile_url
    Rails.application.routes.url_helpers.onboarding_profile_url(
      host: Rails.application.config.action_mailer.default_url_options[:host],
      protocol: Rails.application.config.action_mailer.default_url_options[:protocol]
    )
  end
end