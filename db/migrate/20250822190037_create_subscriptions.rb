class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_subscription_id, null: false
      t.string :stripe_customer_id, null: false
      t.string :status, null: false, default: 'incomplete'
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :trial_end
      t.decimal :amount, precision: 8, scale: 2
      t.string :interval, default: 'month'
      t.string :plan_name, default: 'pro'

      t.timestamps
    end
    
    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, :stripe_customer_id
    add_index :subscriptions, [:user_id, :status]
  end
end
