class UsageMonitoringService
  def initialize(user)
    @user = user
  end
  
  def check_daily_limit_before_upload
    reset_daily_count_if_needed
    
    return true unless @user.can_access_pro_features? # Free tier handled differently
    
    daily_limit = 10
    if @user.daily_photos_uploaded >= daily_limit
      return false
    end
    
    true
  end
  
  def increment_daily_usage!
    reset_daily_count_if_needed
    return unless @user.can_access_pro_features?
    
    @user.increment!(:daily_photos_uploaded)
  end
  
  def check_monthly_usage_and_warn
    return unless @user.can_access_pro_features?
    
    monthly_limit = @user.effective_monthly_photo_limit
    current_usage = @user.current_month_photos
    usage_percentage = (current_usage.to_f / monthly_limit * 100).round
    
    # Determine warning level
    warning_level = case usage_percentage
    when 80..94
      :gentle_warning
    when 95..99
      :approaching_limit
    when 100..109
      :limit_exceeded
    when 110..Float::INFINITY
      :hard_limit
    else
      nil
    end
    
    if warning_level && should_send_warning?(warning_level)
      send_usage_warning(warning_level, current_usage, monthly_limit, usage_percentage)
      update_warning_tracking(warning_level)
    end
    
    warning_level
  end
  
  def can_upload_photo?
    # Check daily limit first
    return false unless check_daily_limit_before_upload
    
    # For Pro users, check if they're past hard limit (110%)
    if @user.can_access_pro_features?
      monthly_limit = @user.effective_monthly_photo_limit
      current_usage = @user.current_month_photos
      usage_percentage = (current_usage.to_f / monthly_limit * 100).round
      
      return false if usage_percentage >= 110 # Hard limit
    end
    
    # For free tier, use existing logic
    @user.can_upload_photo?
  end
  
  def usage_warning_message
    return nil unless @user.can_access_pro_features?
    
    monthly_limit = @user.effective_monthly_photo_limit
    current_usage = @user.current_month_photos
    usage_percentage = (current_usage.to_f / monthly_limit * 100).round
    
    case usage_percentage
    when 80..94
      "You've used #{current_usage}/#{monthly_limit} photos (#{usage_percentage}%) this month. You're doing great!"
    when 95..99
      "You're approaching your monthly limit: #{current_usage}/#{monthly_limit} photos (#{usage_percentage}%). Consider managing usage or upgrading."
    when 100..109
      "You've exceeded your monthly limit (#{usage_percentage}%). You're in the grace period, but please consider upgrading to avoid interruptions."
    when 110..Float::INFINITY
      "You've reached the maximum usage limit (#{usage_percentage}%). Please upgrade to continue uploading photos."
    else
      nil
    end
  end
  
  private
  
  def reset_daily_count_if_needed
    today = Date.current
    if @user.last_daily_reset != today
      @user.update!(
        daily_photos_uploaded: 0,
        last_daily_reset: today
      )
    end
  end
  
  def should_send_warning?(warning_level)
    # Don't spam warnings - only send each level once per month
    return false if @user.last_warning_sent_at && @user.last_warning_sent_at > 1.week.ago
    
    # Only send warnings if we haven't sent this level recently
    case warning_level
    when :gentle_warning
      @user.usage_warnings_sent == 0 || @user.last_warning_sent_at < 1.month.ago
    when :approaching_limit
      @user.usage_warnings_sent <= 1
    when :limit_exceeded
      @user.usage_warnings_sent <= 2
    when :hard_limit
      @user.usage_warnings_sent <= 3
    else
      false
    end
  end
  
  def send_usage_warning(level, current_usage, monthly_limit, percentage)
    begin
      UsageWarningMailer.send("#{level}_warning", @user, {
        current_usage: current_usage,
        monthly_limit: monthly_limit,
        percentage: percentage,
        days_remaining: days_until_billing_reset
      }).deliver_now
      
      Rails.logger.info "Sent #{level} warning to user #{@user.id} (#{current_usage}/#{monthly_limit} photos)"
    rescue => e
      Rails.logger.error "Failed to send usage warning to user #{@user.id}: #{e.message}"
    end
  end
  
  def update_warning_tracking(level)
    @user.update!(
      usage_warnings_sent: @user.usage_warnings_sent + 1,
      last_warning_sent_at: Time.current
    )
    
    # Track violations for hard limits
    if level == :hard_limit
      @user.increment!(:fair_use_violations)
    end
  end
  
  def days_until_billing_reset
    # Calculate days until next billing cycle
    # This is a simplified version - you might want to use actual subscription billing dates
    today = Date.current
    next_month = today.next_month.beginning_of_month
    (next_month - today).to_i
  end
end