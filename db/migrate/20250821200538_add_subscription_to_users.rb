class AddSubscriptionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :subscription_tier, :string, default: 'starter'
    add_column :users, :subscription_status, :string, default: 'trial'
    add_column :users, :subscription_started_at, :datetime
    add_column :users, :trial_ends_at, :datetime
    
    # Set trial end date for existing users (7 days from now)
    User.update_all(trial_ends_at: 7.days.from_now) if User.exists?
  end
end
