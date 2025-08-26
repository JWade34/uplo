class TestEmailsController < ApplicationController
  # Authentication is already handled by ApplicationController
  
  def send_test
    if Current.user.email_address.include?('@superdupr.com') || Current.user.email_address == 'justinmckelvey@gmail.com'
      # Send all 5 emails immediately
      UserMailer.welcome_email(Current.user).deliver_later
      UserMailer.getting_started_tips(Current.user).deliver_later
      UserMailer.common_mistakes(Current.user).deliver_later
      UserMailer.success_stories(Current.user).deliver_later
      UserMailer.final_conversion(Current.user).deliver_later
      
      redirect_to dashboard_path, notice: "Test emails queued for delivery to #{Current.user.email_address}!"
    else
      redirect_to dashboard_path, alert: "Test emails only available for admin users"
    end
  end
end