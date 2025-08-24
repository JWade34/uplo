class AddAdminToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
    
    # Set your account as admin
    User.find_by(email_address: 'justin+hi@superdupr.com')&.update!(admin: true)
  end
end
