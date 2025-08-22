class CreateEarlyAccessSignups < ActiveRecord::Migration[8.0]
  def change
    create_table :early_access_signups do |t|
      t.string :name
      t.string :email
      t.string :business_type
      t.text :current_challenge
      t.boolean :marketing_emails

      t.timestamps
    end
  end
end
