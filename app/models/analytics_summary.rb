class AnalyticsSummary < ApplicationRecord
  belongs_to :user
  belongs_to :best_performing_post, class_name: 'Photo', optional: true
  
  validates :total_posts, :followers_gained, presence: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :avg_engagement_rate, presence: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :period_start, :period_end, presence: true
  validates :tier_at_time, presence: true, inclusion: { 
    in: %w[starter pro enterprise],
    message: "%{value} is not a valid tier" 
  }
  
  validate :period_end_after_start
  
  # Scopes
  scope :recent, -> { order(period_end: :desc) }
  scope :by_tier, ->(tier) { where(tier_at_time: tier) }
  scope :last_month, -> { where(period_end: 1.month.ago..Time.current) }
  
  # Helper methods
  def period_days
    (period_end - period_start).to_i + 1
  end
  
  def posts_per_day
    return 0 if period_days.zero?
    (total_posts.to_f / period_days).round(1)
  end
  
  def followers_per_day
    return 0 if period_days.zero?
    (followers_gained.to_f / period_days).round(1)
  end
  
  def period_display
    "#{period_start.strftime('%b %d')} - #{period_end.strftime('%b %d, %Y')}"
  end
  
  def tier_display
    tier_at_time.titleize
  end
  
  private
  
  def period_end_after_start
    return unless period_start && period_end
    
    if period_end <= period_start
      errors.add(:period_end, 'must be after period start')
    end
  end
end
