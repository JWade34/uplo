class AddUsageTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :usage_warnings_sent, :integer, default: 0
    add_column :users, :last_warning_sent_at, :datetime
    add_column :users, :fair_use_violations, :integer, default: 0
    add_column :users, :daily_photos_uploaded, :integer, default: 0
    add_column :users, :last_daily_reset, :date
  end
end
