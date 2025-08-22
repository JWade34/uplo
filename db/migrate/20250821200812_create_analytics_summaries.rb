class CreateAnalyticsSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_summaries do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :total_posts
      t.decimal :avg_engagement_rate, precision: 5, scale: 2
      t.references :best_performing_post, null: true, foreign_key: { to_table: :photos }
      t.integer :followers_gained
      t.date :period_start
      t.date :period_end
      t.string :tier_at_time

      t.timestamps
    end
  end
end
