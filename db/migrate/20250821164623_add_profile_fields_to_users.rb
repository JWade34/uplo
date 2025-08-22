class AddProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :bio, :text
    add_column :users, :fitness_focus, :string
    add_column :users, :target_audience, :string
    add_column :users, :tone_preference, :string
    add_column :users, :business_type, :string
    add_column :users, :onboarding_completed, :boolean, default: false
  end
end
