class AdminController < ApplicationController
  allow_unauthenticated_access
  before_action :require_admin_authentication, except: [:login]
  before_action :log_admin_activity
  
  ADMIN_PASSWORD = ENV.fetch('ADMIN_PASSWORD', 'temppass123')
  ALLOWED_IPS = ENV.fetch('ADMIN_ALLOWED_IPS', '127.0.0.1,::1').split(',').map(&:strip)
  
  def index
    begin
      @stats = {
        total_users: User.count || 0,
        active_users: User.joins(:sessions).where('sessions.created_at > ?', 7.days.ago).distinct.count || 0,
        total_photos: Photo.count || 0,
        photos_this_month: Photo.where(created_at: Time.current.beginning_of_month..Time.current).count || 0,
        processing_photos: Photo.where(processed: false).count || 0,
        active_subscriptions: Subscription.active.count || 0,
        revenue_this_month: calculate_monthly_revenue || 0,
        system_health: check_system_health || {}
      }
      
      @recent_users = User.order(created_at: :desc).limit(5)
      @recent_photos = Photo.order(created_at: :desc).limit(5)
      @failed_jobs = get_failed_jobs.first(5) || []
    rescue => e
      Rails.logger.error "Admin dashboard error: #{e.message}"
      @stats = {
        total_users: 0,
        active_users: 0,
        total_photos: 0,
        photos_this_month: 0,
        processing_photos: 0,
        active_subscriptions: 0,
        revenue_this_month: 0,
        system_health: { database: false, storage: false, jobs: false, overall: false }
      }
      @recent_users = []
      @recent_photos = []
      @failed_jobs = []
      @error = "Error loading dashboard data: #{e.message}"
    end
  end
  
  def users
    begin
      @users = User.includes(:photos)
                   .order(params[:sort] || 'created_at DESC')
                   .limit(50)  # Simple limit instead of pagination
      
      if params[:search].present?
        @users = @users.where('email_address ILIKE ?', "%#{params[:search]}%")
      end
      
      if params[:subscription_status].present?
        case params[:subscription_status]
        when 'active'
          @users = @users.where(subscription_status: ['active', 'trial'])
        when 'inactive'
          @users = @users.where(subscription_status: ['expired', 'cancelled'])
        end
      end
    rescue => e
      Rails.logger.error "Admin users error: #{e.message}"
      @users = []
      @error = "Error loading users: #{e.message}"
    end
  end
  
  def user_details
    @user = User.find(params[:id])
    @subscriptions = @user.subscriptions.order(created_at: :desc)
    @photos = @user.photos.order(created_at: :desc).limit(10)
    @sessions = @user.sessions.order(created_at: :desc).limit(5)
    
    render json: {
      user: @user.as_json(include: :subscriptions),
      stats: {
        photos_count: @user.photos.count,
        photos_this_month: @user.current_month_photos,
        captions_count: Caption.joins(:photo).where(photos: { user: @user }).count,
        last_login: @user.sessions.maximum(:created_at),
        account_created: @user.created_at
      },
      recent_photos: @photos.as_json(include: :captions),
      recent_sessions: @sessions.as_json
    }
  end
  
  def fix_user_limits
    @user = User.find(params[:id])
    
    # Reset monthly counters
    @user.update!(
      current_month_photos: 0,
      current_month_captions: 0,
      monthly_reset_date: Time.current.beginning_of_month
    )
    
    # Create Pro subscription if needed
    unless @user.has_active_subscription?
      @user.subscriptions.create!(
        plan_id: 'pro_yearly',
        status: 'trialing',
        current_period_start: Time.current,
        current_period_end: 30.days.from_now,
        trial_end: 30.days.from_now,
        stripe_subscription_id: "admin_#{SecureRandom.hex(8)}"
      )
    end
    
    log_admin_action("Fixed limits for user #{@user.email}")
    
    render json: {
      success: true,
      message: "Successfully reset limits and added Pro subscription for #{@user.email}",
      user: @user.reload.as_json
    }
  end
  
  def system_status
    render json: {
      database: check_database_connection,
      storage: check_storage_status,
      external_apis: check_external_apis,
      background_jobs: get_job_stats,
      memory_usage: get_memory_usage,
      disk_space: get_disk_usage
    }
  end
  
  def photos
    @photos = Photo.includes(:user, :captions)
                   .order(params[:sort] || 'created_at DESC')
                   .page(params[:page])
                   .per(20)
    
    case params[:filter]
    when 'processing'
      @photos = @photos.where(processed: false)
    when 'failed'
      @photos = @photos.where(processed: false).where('created_at < ?', 10.minutes.ago)
    when 'recent'
      @photos = @photos.where(created_at: 24.hours.ago..Time.current)
    end
    
    @stats = {
      total: Photo.count,
      processing: Photo.where(processed: false).count,
      processed: Photo.where(processed: true).count,
      with_captions: Photo.joins(:captions).distinct.count,
      without_captions: Photo.left_joins(:captions).where(captions: { id: nil }).count
    }
  end
  
  def cleanup_photos
    case params[:action_type]
    when 'delete_unprocessed'
      deleted = Photo.where(processed: false, created_at: ..1.hour.ago).destroy_all
      message = "Deleted #{deleted.length} unprocessed photos older than 1 hour"
    when 'delete_test_photos'
      deleted = Photo.joins(:user).where(users: { email: ['test@example.com', 'admin@test.com'] }).destroy_all
      message = "Deleted #{deleted.length} test photos"
    when 'reprocess_failed'
      failed_photos = Photo.where(processed: false, created_at: ..10.minutes.ago)
      failed_photos.each { |photo| PhotoProcessingJob.perform_later(photo.id) }
      message = "Requeued #{failed_photos.count} failed photos for processing"
    else
      return render json: { error: 'Invalid action type' }, status: 400
    end
    
    log_admin_action(message)
    render json: { success: true, message: message }
  end
  
  def analytics
    @analytics = {
      user_growth: calculate_user_growth,
      photo_stats: calculate_photo_stats,
      revenue_stats: calculate_revenue_stats,
      usage_patterns: calculate_usage_patterns,
      popular_features: calculate_feature_usage
    }
  end
  
  def login
    if request.post?
      begin
        Rails.logger.info "Admin login attempt - Submitted: '#{params[:password]}', Expected: '#{ADMIN_PASSWORD}', IP allowed: #{ip_allowed?}"
        
        if params[:password] == ADMIN_PASSWORD && ip_allowed?
          session[:admin_authenticated] = true
          session[:admin_login_time] = Time.current
          # Skip logging temporarily to avoid issues
          # log_admin_action("Admin login from IP: #{request.remote_ip}")
          redirect_to "/admin/fix-justin" and return
        else
          @error = "Invalid password or IP not allowed (Debug: submitted='#{params[:password]}', expected='#{ADMIN_PASSWORD}', ip_ok=#{ip_allowed?})"
          log_admin_action("Failed admin login attempt from IP: #{request.remote_ip}")
          render :login and return
        end
      rescue => e
        Rails.logger.error "Admin login error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        @error = "Login system error. Please contact administrator."
        render :login and return
      end
    end
  end
  
  def fix_justin
    begin
      user = User.find_by(email_address: 'justin+hi@superdupr.com')
      
      if user
        # Reset monthly counters
        user.update!(
          current_month_photos: 0,
          current_month_captions: 0,
          last_usage_reset: Time.current
        )
        
        # Set user to Pro tier
        user.update!(
          subscription_tier: 'pro',
          subscription_status: 'active',
          trial_ends_at: 30.days.from_now
        )
        
        @message = "✅ Successfully fixed account for #{user.email_address}!"
        @details = "Monthly photos reset to 0, Pro access enabled"
        @user = user
      else
        @message = "❌ User not found: justin+hi@superdupr.com"
      end
    rescue => e
      Rails.logger.error "Fix Justin error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @message = "❌ Error: #{e.message}"
      @error_details = e.backtrace.first(3).join("\n")
    end
  end

  def logout
    session.delete(:admin_authenticated)
    session.delete(:admin_login_time)
    redirect_to admin_login_path
  end
  
  private
  
  def require_admin_authentication
    unless session[:admin_authenticated] && ip_allowed?
      redirect_to admin_login_path and return
    end
    
    # Session timeout after 2 hours
    if session[:admin_login_time] && session[:admin_login_time] < 2.hours.ago
      session.delete(:admin_authenticated)
      redirect_to admin_login_path and return
    end
  end
  
  def ip_allowed?
    return true if Rails.env.development?
    # Re-enable IP restrictions for security
    ALLOWED_IPS.include?(request.remote_ip)
  end
  
  def log_admin_activity
    return if action_name == 'login'
    log_admin_action("Accessed #{controller_name}##{action_name}")
  end
  
  def log_admin_action(action)
    begin
      Rails.logger.info "[ADMIN] #{Time.current.iso8601} - IP: #{request.remote_ip} - #{action}"
      # Could also store in database for audit trail
    rescue => e
      Rails.logger.error "Admin logging error: #{e.message}"
    end
  end
  
  def calculate_monthly_revenue
    current_month_subs = Subscription.active
                                    .where(current_period_start: Time.current.beginning_of_month..Time.current)
    
    revenue = 0
    current_month_subs.each do |sub|
      case sub.plan_id
      when 'pro_monthly'
        revenue += 39
      when 'pro_yearly'
        revenue += 390
      end
    end
    revenue
  end
  
  def check_system_health
    {
      database: check_database_connection,
      storage: Photo.count > 0,
      jobs: get_failed_jobs.empty?,
      overall: true
    }
  rescue
    { database: false, storage: false, jobs: false, overall: false }
  end
  
  def check_database_connection
    ActiveRecord::Base.connection.active?
  rescue
    false
  end
  
  def check_storage_status
    return { available: true, used_space: "N/A" } unless Rails.env.production?
    
    # Basic storage check
    { 
      available: true,
      used_space: Photo.sum(:file_size) || 0,
      photo_count: Photo.count
    }
  end
  
  def check_external_apis
    {
      openai: ENV['OPENAI_API_KEY'].present?,
      stripe: ENV['STRIPE_SECRET_KEY'].present?,
      resend: ENV['RESEND_API_KEY'].present?
    }
  end
  
  def get_job_stats
    {
      failed: get_failed_jobs.count,
      processing: Photo.where(processed: false).count,
      total_processed: Photo.where(processed: true).count
    }
  end
  
  def get_failed_jobs
    # Since we're using async adapter in development, we'll check for stuck photos
    Photo.where(processed: false).where('created_at < ?', 10.minutes.ago)
  end
  
  def get_memory_usage
    return "N/A" unless Rails.env.production?
    
    begin
      `free -m`.split("\n")[1].split[2].to_i
    rescue
      "N/A"
    end
  end
  
  def get_disk_usage
    return "N/A" unless Rails.env.production?
    
    begin
      `df -h /`.split("\n")[1].split[4]
    rescue
      "N/A"
    end
  end
  
  def calculate_user_growth
    {
      total: User.count,
      this_month: User.where(created_at: Time.current.beginning_of_month..Time.current).count,
      last_month: User.where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month).count,
      growth_rate: calculate_growth_rate('users')
    }
  end
  
  def calculate_photo_stats
    {
      total: Photo.count,
      this_month: Photo.where(created_at: Time.current.beginning_of_month..Time.current).count,
      processed: Photo.where(processed: true).count,
      processing: Photo.where(processed: false).count,
      avg_per_user: Photo.count.to_f / [User.count, 1].max
    }
  end
  
  def calculate_revenue_stats
    {
      monthly: calculate_monthly_revenue,
      annual: Subscription.active.where(plan_id: 'pro_yearly').count * 390,
      total_subscribers: Subscription.active.count,
      trial_users: Subscription.where(status: 'trialing').count
    }
  end
  
  def calculate_usage_patterns
    {
      peak_upload_hour: Photo.group("EXTRACT(hour FROM created_at)").count.max_by { |_, count| count }&.first || 0,
      avg_photos_per_user: Photo.count.to_f / [User.count, 1].max,
      most_active_day: Photo.group("EXTRACT(dow FROM created_at)").count.max_by { |_, count| count }&.first || 0
    }
  end
  
  def calculate_feature_usage
    {
      heic_uploads: Photo.where(content_type: ['image/heic', 'image/heif']).count,
      total_captions: Caption.count,
      avg_captions_per_photo: Caption.count.to_f / [Photo.where(processed: true).count, 1].max
    }
  end
  
  def calculate_growth_rate(metric)
    case metric
    when 'users'
      this_month = User.where(created_at: Time.current.beginning_of_month..Time.current).count
      last_month = User.where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month).count
    else
      return 0
    end
    
    return 0 if last_month.zero?
    ((this_month - last_month).to_f / last_month * 100).round(1)
  end
end