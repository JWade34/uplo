class AddPasswordToEarlyAccessSignups < ActiveRecord::Migration[8.0]
  def change
    add_column :early_access_signups, :password, :string
  end
end
