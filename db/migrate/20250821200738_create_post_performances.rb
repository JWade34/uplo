class CreatePostPerformances < ActiveRecord::Migration[8.0]
  def change
    create_table :post_performances do |t|
      t.references :photo, null: false, foreign_key: true
      t.string :platform
      t.integer :likes
      t.integer :comments
      t.integer :shares
      t.integer :reach
      t.decimal :engagement_rate, precision: 5, scale: 2
      t.datetime :posted_at

      t.timestamps
    end
  end
end
