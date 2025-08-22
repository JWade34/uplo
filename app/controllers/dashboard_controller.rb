class DashboardController < ApplicationController
  before_action :require_authentication
  before_action :redirect_to_onboarding_if_needed
  
  def index
    @user = Current.user
    load_dashboard_data
  end
  
  private
  
  def redirect_to_onboarding_if_needed
    redirect_to onboarding_path if Current.user.needs_onboarding?
  end
  
  def load_dashboard_data
    # Performance data based on subscription tier
    if @user.can_access_pro_features?
      load_pro_dashboard_data
    else
      load_starter_dashboard_data
    end
    
    # Common data for all users
    @latest_summary = @user.analytics_summaries.recent.first
    @total_photos = @user.photos.count
    @processed_photos = @user.photos.processed.count
  end
  
  def load_starter_dashboard_data
    # Limited data for starter users - last 7 days only
    @recent_performances = PostPerformance.joins(photo: :user)
                                          .where(users: { id: @user.id })
                                          .where('posted_at >= ?', 7.days.ago)
                                          .recent
    
    @avg_engagement = @recent_performances.average(:engagement_rate) || 0
    @top_posts = @recent_performances.order(engagement_rate: :desc).limit(3)
    @total_engagement = @recent_performances.sum(&:total_engagement)
    
    # Show blurred preview of locked posts (posts 4-10)
    @locked_posts_preview = PostPerformance.joins(photo: :user)
                                           .where(users: { id: @user.id })
                                           .order(engagement_rate: :desc)
                                           .offset(3)
                                           .limit(7)
    
    # Calculate upgrade potential (what they're missing)
    @potential_followers = calculate_upgrade_potential
    @locked_features = get_locked_features
    @usage_stats = get_usage_stats
    @value_gaps = calculate_value_gaps
  end
  
  def load_pro_dashboard_data
    # Full analytics for pro users
    @all_performances = PostPerformance.joins(photo: :user)
                                       .where(users: { id: @user.id })
                                       .last_90_days
    
    @avg_engagement = @all_performances.average(:engagement_rate) || 0
    @top_posts = @all_performances.order(engagement_rate: :desc).limit(5)
    @total_engagement = @all_performances.sum(&:total_engagement)
    
    # Platform breakdown
    @platform_stats = @all_performances.group(:platform)
                                       .average(:engagement_rate)
                                       .transform_keys(&:titleize)
    
    # Monthly growth trends
    @monthly_trends = @user.analytics_summaries.recent.limit(6)
  end
  
  def calculate_upgrade_potential
    return 0 unless @user.starter?
    
    # Estimate potential followers with pro features
    current_avg = @avg_engagement || 2.0
    pro_avg = current_avg * 1.8 # Pro users typically see 80% better engagement
    
    posts_per_month = @recent_performances.count # Using current 7-day data
    return 0 if posts_per_month.zero?
    
    # Calculate potential monthly follower gain with pro features
    potential_monthly_gain = (pro_avg * posts_per_month * 4 * 0.8).to_i # 4 weeks per month
    current_monthly_gain = (current_avg * posts_per_month * 4 * 0.5).to_i
    
    potential_monthly_gain - current_monthly_gain
  end
  
  def calculate_value_gaps
    return {} unless @user.starter?
    
    current_performance = {
      engagement_rate: @avg_engagement || 2.0,
      posts_per_week: @recent_performances.count,
      total_engagement: @total_engagement || 0
    }
    
    # Pro user benchmarks (simulated based on typical improvements)
    pro_performance = {
      engagement_rate: current_performance[:engagement_rate] * 1.8,
      posts_per_week: [current_performance[:posts_per_week] * 1.5, 8].min, # More content due to better captions
      total_engagement: current_performance[:total_engagement] * 2.2
    }
    
    {
      current: current_performance,
      pro: pro_performance,
      missed_engagement: pro_performance[:total_engagement] - current_performance[:total_engagement],
      missed_reach: ((pro_performance[:total_engagement] - current_performance[:total_engagement]) * 12).to_i, # Rough reach multiplier
      potential_followers: calculate_upgrade_potential,
      weekly_opportunity_cost: (pro_performance[:total_engagement] - current_performance[:total_engagement]) / 4 # Per week
    }
  end
  
  def get_locked_features
    [
      {
        title: "Advanced Analytics",
        description: "Full 90-day performance history with detailed breakdowns",
        icon: "📊"
      },
      {
        title: "Platform Comparison", 
        description: "See which platforms perform best for your content",
        icon: "📱"
      },
      {
        title: "Competitor Analysis",
        description: "Compare your performance to similar fitness accounts",
        icon: "🔍"
      },
      {
        title: "Growth Predictions",
        description: "AI-powered forecasts for follower and engagement growth",
        icon: "📈"
      },
      {
        title: "Content Optimization",
        description: "Personalized recommendations to boost your engagement",
        icon: "🎯"
      }
    ]
  end
  
  def get_usage_stats
    @user.reset_monthly_usage_if_needed
    {
      photos_used: @user.current_month_photos,
      photos_limit: @user.effective_monthly_photo_limit,
      photos_remaining: @user.photos_remaining_this_month,
      captions_used: @user.current_month_captions,
      captions_limit: @user.effective_monthly_caption_limit,
      captions_remaining: @user.captions_remaining_this_month,
      photos_percentage: @user.usage_percentage(:photos),
      captions_percentage: @user.usage_percentage(:captions)
    }
  end
end
