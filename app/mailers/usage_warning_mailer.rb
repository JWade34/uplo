class UsageWarningMailer < ApplicationMailer
  def gentle_warning(user, usage_data)
    @user = user
    @usage_data = usage_data
    @name = user.full_name.present? ? user.full_name.split.first : 'there'
    
    mail(
      to: user.email_address,
      subject: "#{@usage_data[:percentage]}% of your monthly photos used - You're doing great! 📸"
    )
  end
  
  def approaching_limit(user, usage_data)
    @user = user
    @usage_data = usage_data
    @name = user.full_name.present? ? user.full_name.split.first : 'there'
    
    mail(
      to: user.email_address,
      subject: "⚠️ Approaching your monthly photo limit (#{@usage_data[:percentage]}% used)"
    )
  end
  
  def limit_exceeded(user, usage_data)
    @user = user
    @usage_data = usage_data
    @name = user.full_name.present? ? user.full_name.split.first : 'there'
    
    mail(
      to: user.email_address,
      subject: "Grace period: You've exceeded your monthly photo limit"
    )
  end
  
  def hard_limit(user, usage_data)
    @user = user
    @usage_data = usage_data
    @name = user.full_name.present? ? user.full_name.split.first : 'there'
    
    mail(
      to: user.email_address,
      subject: "🔒 Photo uploads temporarily paused - Let's get you back on track"
    )
  end
end