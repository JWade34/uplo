class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :photos, dependent: :destroy
  has_many :analytics_summaries, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_one_attached :profile_picture

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  
  validate :profile_picture_validation, if: -> { profile_picture.attached? }
  
  # Profile enums for AI personalization
  enum :fitness_focus, {
    strength_training: 'strength_training',
    cardio: 'cardio', 
    yoga: 'yoga',
    crossfit: 'crossfit',
    bodybuilding: 'bodybuilding',
    functional_fitness: 'functional_fitness',
    weight_loss: 'weight_loss',
    general_fitness: 'general_fitness'
  }, allow_nil: true
  
  enum :target_audience, {
    beginners: 'beginners',
    intermediate: 'intermediate', 
    advanced: 'advanced',
    all_levels: 'all_levels',
    women: 'women',
    men: 'men',
    seniors: 'seniors',
    athletes: 'athletes'
  }, allow_nil: true
  
  enum :tone_preference, {
    motivational: 'motivational',
    educational: 'educational',
    fun_casual: 'fun_casual',
    professional: 'professional',
    inspiring: 'inspiring',
    community_focused: 'community_focused'
  }, allow_nil: true
  
  enum :business_type, {
    personal_trainer: 'personal_trainer',
    gym_owner: 'gym_owner',
    fitness_coach: 'fitness_coach',
    yoga_instructor: 'yoga_instructor',
    nutritionist: 'nutritionist',
    fitness_influencer: 'fitness_influencer',
    other: 'other'
  }, allow_nil: true
  
  # Subscription enums
  enum :subscription_tier, {
    starter: 'starter',
    pro: 'pro',
    enterprise: 'enterprise'
  }, default: 'starter'
  
  enum :subscription_status, {
    trial: 'trial',
    active: 'active',
    expired: 'expired', 
    cancelled: 'cancelled'
  }, default: 'trial'
  
  # Scopes
  scope :onboarding_incomplete, -> { where(onboarding_completed: false) }
  scope :onboarding_complete, -> { where(onboarding_completed: true) }
  
  # Helper methods
  def needs_onboarding?
    !onboarding_completed?
  end
  
  def profile_complete?
    bio.present? && fitness_focus.present? && target_audience.present? && 
    tone_preference.present? && business_type.present?
  end
  
  # Subscription helper methods
  def active_subscription
    @active_subscription ||= subscriptions.active.order(created_at: :desc).first
  end
  
  def trial_active?
    active_subscription&.trial_active? || (trial? && trial_ends_at.present? && trial_ends_at > Time.current)
  end
  
  def trial_expired?
    trial? && trial_ends_at.present? && trial_ends_at <= Time.current
  end
  
  def subscription_active?
    active_subscription&.provides_pro_access? || active? || trial_active?
  end
  
  def can_access_pro_features?
    # Check Stripe subscription first, then fallback to legacy fields
    active_subscription&.provides_pro_access? || pro? || enterprise?
  end
  
  def days_left_in_trial
    if active_subscription&.trial_active?
      active_subscription.trial_days_remaining
    elsif trial_active?
      ((trial_ends_at - Time.current) / 1.day).ceil
    else
      0
    end
  end
  
  def subscription_display_name
    if active_subscription
      active_subscription.plan_name.humanize
    else
      case subscription_tier
      when 'starter' then 'Starter'
      when 'pro' then 'Pro'
      when 'enterprise' then 'Enterprise'
      end
    end
  end
  
  def subscription_status_display
    active_subscription&.status_display || 'Free Account'
  end
  
  def subscription_price_display
    active_subscription&.price_display || 'Free'
  end
  
  def has_stripe_subscription?
    active_subscription.present?
  end
  
  def has_active_subscription?
    subscription_active?
  end
  
  def needs_payment_attention?
    active_subscription&.needs_attention? || false
  end
  
  # Monthly usage tracking methods
  def reset_monthly_usage_if_needed
    return unless last_usage_reset.nil? || last_usage_reset.beginning_of_month < Time.current.beginning_of_month
    
    update!(
      current_month_photos: 0,
      current_month_captions: 0,
      last_usage_reset: Time.current
    )
  end
  
  def effective_monthly_photo_limit
    if can_access_pro_features?
      250  # Professional grade limit for Pro users
    else
      monthly_photo_limit
    end
  end
  
  def effective_monthly_caption_limit
    if can_access_pro_features?
      750  # 3 captions per photo * 250 photos
    else
      monthly_caption_limit
    end
  end
  
  def photos_remaining_this_month
    if can_access_pro_features?
      reset_monthly_usage_if_needed
      [effective_monthly_photo_limit - current_month_photos, 0].max
    else
      # For free tier, use total photos limit (5 total, not monthly)
      total_photos_used = photos.count
      [5 - total_photos_used, 0].max
    end
  end
  
  def captions_remaining_this_month
    if can_access_pro_features?
      reset_monthly_usage_if_needed
      [effective_monthly_caption_limit - current_month_captions, 0].max
    else
      # For free tier, use total captions limit (5 total captions)
      total_captions_used = photos.sum { |photo| photo.captions.count }
      [5 - total_captions_used, 0].max
    end
  end
  
  def can_upload_photo?
    photos_remaining_this_month > 0
  end
  
  def can_generate_caption?
    captions_remaining_this_month > 0
  end
  
  def increment_photo_usage!
    if can_access_pro_features?
      reset_monthly_usage_if_needed
      increment!(:current_month_photos)
    end
    # For free tier, we don't need to increment counters since we count actual photos
  end
  
  def increment_caption_usage!
    if can_access_pro_features?
      reset_monthly_usage_if_needed
      increment!(:current_month_captions)
    end
    # For free tier, we don't need to increment counters since we count actual captions
  end
  
  def usage_percentage(type)
    case type
    when :photos
      if can_access_pro_features?
        (current_month_photos.to_f / effective_monthly_photo_limit * 100).round
      else
        # For free tier, show percentage of total 5 photos used
        total_photos_used = photos.count
        (total_photos_used.to_f / 5 * 100).round
      end
    when :captions
      if can_access_pro_features?
        (current_month_captions.to_f / effective_monthly_caption_limit * 100).round
      else
        # For free tier, show percentage of total 5 captions used
        total_captions_used = photos.sum { |photo| photo.captions.count }
        (total_captions_used.to_f / 5 * 100).round
      end
    end
  end
  
  private
  
  def profile_picture_validation
    if profile_picture.attached?
      unless profile_picture.content_type.in?(%w[image/jpeg image/jpg image/png image/gif])
        errors.add(:profile_picture, 'must be a valid image format (JPEG, PNG, or GIF)')
      end
      
      if profile_picture.byte_size > 5.megabytes
        errors.add(:profile_picture, 'should be less than 5MB')
      end
    end
  end
end
