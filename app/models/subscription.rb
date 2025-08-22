class Subscription < ApplicationRecord
  belongs_to :user
  
  # Stripe subscription statuses
  STATUSES = %w[
    incomplete incomplete_expired trialing active 
    past_due canceled unpaid paused
  ].freeze
  
  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :stripe_customer_id, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :interval, inclusion: { in: %w[month year] }
  validates :plan_name, presence: true
  
  scope :active, -> { where(status: ['active', 'trialing']) }
  scope :inactive, -> { where(status: ['canceled', 'unpaid', 'past_due']) }
  scope :past_due, -> { where(status: 'past_due') }
  scope :trialing, -> { where(status: 'trialing') }
  
  # Check if subscription provides pro access
  def provides_pro_access?
    %w[active trialing].include?(status) && current_period_end&.future?
  end
  
  # Check if subscription is in trial
  def trial_active?
    status == 'trialing' && trial_end&.future?
  end
  
  # Check if subscription needs payment attention
  def needs_attention?
    %w[past_due incomplete].include?(status)
  end
  
  # Days remaining in trial
  def trial_days_remaining
    return 0 unless trial_active?
    ((trial_end - Time.current) / 1.day).ceil
  end
  
  # Days until subscription ends
  def days_until_renewal
    return 0 unless current_period_end
    ((current_period_end - Time.current) / 1.day).ceil
  end
  
  # Human readable status
  def status_display
    case status
    when 'trialing' then "Free Trial (#{trial_days_remaining} days left)"
    when 'active' then "Active (renews #{current_period_end&.strftime('%b %d')})"
    when 'past_due' then 'Payment Past Due'
    when 'canceled' then 'Canceled'
    when 'incomplete' then 'Payment Incomplete'
    else status.humanize
    end
  end
  
  # Pricing display
  def price_display
    return "Free Trial" if trial_active?
    
    formatted_amount = "$#{amount.to_i}"
    case interval
    when 'month' then "#{formatted_amount}/month"
    when 'year' then "#{formatted_amount}/year"
    else formatted_amount
    end
  end
end
