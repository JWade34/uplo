class AddAdvancedProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :client_pain_points, :text
    add_column :users, :unique_approach, :text
    add_column :users, :brand_personality, :string
    add_column :users, :sample_caption, :text
    add_column :users, :call_to_action_preference, :string
    add_column :users, :location, :string
    add_column :users, :price_range, :string
    add_column :users, :posting_frequency, :string
    add_column :users, :favorite_hashtags, :text
    add_column :users, :words_to_avoid, :text
  end
end
