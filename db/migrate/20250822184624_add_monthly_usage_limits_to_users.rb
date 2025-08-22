class AddMonthlyUsageLimitsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :monthly_photo_limit, :integer, default: 8
    add_column :users, :monthly_caption_limit, :integer, default: 5
    add_column :users, :current_month_photos, :integer, default: 0
    add_column :users, :current_month_captions, :integer, default: 0
    add_column :users, :last_usage_reset, :datetime, default: -> { 'CURRENT_TIMESTAMP' }
  end
end
