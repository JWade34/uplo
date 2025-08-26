class AddEmailFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :unsubscribe_token, :string
    add_column :users, :email_preferences, :boolean, default: true, null: false
    
    add_index :users, :unsubscribe_token, unique: true
  end
end
