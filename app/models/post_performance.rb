class PostPerformance < ApplicationRecord
  belongs_to :photo
  
  # Platform validation
  validates :platform, presence: true, inclusion: { 
    in: %w[instagram facebook tiktok linkedin twitter],
    message: "%{value} is not a supported platform" 
  }
  
  validates :likes, :comments, :shares, :reach, presence: true, 
            numericality: { greater_than_or_equal_to: 0 }
  validates :engagement_rate, presence: true, 
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :posted_at, presence: true
  
  # Scopes
  scope :recent, -> { order(posted_at: :desc) }
  scope :by_platform, ->(platform) { where(platform: platform) }
  scope :high_engagement, -> { where('engagement_rate > ?', 5.0) }
  scope :last_30_days, -> { where(posted_at: 30.days.ago..Time.current) }
  scope :last_90_days, -> { where(posted_at: 90.days.ago..Time.current) }
  
  # Helper methods
  def total_engagement
    likes + comments + shares
  end
  
  def engagement_percentage
    return 0 if reach.zero?
    (total_engagement.to_f / reach * 100).round(2)
  end
  
  def platform_display_name
    platform.titleize
  end
  
  def performance_level
    case engagement_rate
    when 0..2 then 'Low'
    when 2..5 then 'Average' 
    when 5..10 then 'Good'
    else 'Excellent'
    end
  end
end
