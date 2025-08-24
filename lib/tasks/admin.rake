namespace :admin do
  desc "Fix user upload limits and add pro subscription"
  task :fix_user_limits, [:email] => :environment do |t, args|
    email = args[:email] || ENV['USER_EMAIL']
    
    unless email
      puts "Usage: bin/rails admin:fix_user_limits['your@email.com']"
      puts "   or: USER_EMAIL=your@email.com bin/rails admin:fix_user_limits"
      exit
    end
    
    user = User.find_by(email: email)
    unless user
      puts "❌ User not found with email: #{email}"
      puts "Available users:"
      User.limit(10).pluck(:email).each { |e| puts "  - #{e}" }
      exit
    end
    
    puts "Found user: #{user.email}"
    puts "Current status:"
    puts "  - Photos this month: #{user.current_month_photos}"
    puts "  - Photo limit: #{user.effective_monthly_photo_limit}"
    puts "  - Can upload?: #{user.can_upload_photo?}"
    puts "  - Has active subscription?: #{user.has_active_subscription?}"
    
    # Reset monthly usage
    user.update!(
      current_month_photos: 0,
      current_month_captions: 0,
      monthly_reset_date: Time.current.beginning_of_month
    )
    puts "✅ Reset monthly usage counters"
    
    # Create or update Pro subscription if not exists
    active_sub = user.subscriptions.active.first
    if active_sub
      puts "✅ Already has active subscription: #{active_sub.plan_id}"
    else
      subscription = user.subscriptions.build(
        plan_id: 'pro_yearly',
        status: 'trialing',
        current_period_start: Time.current,
        current_period_end: 30.days.from_now,
        trial_end: 30.days.from_now,
        stripe_subscription_id: "test_#{SecureRandom.hex(8)}"
      )
      
      if subscription.save
        puts "✅ Created Pro trial subscription"
      else
        puts "❌ Failed to create subscription: #{subscription.errors.full_messages}"
      end
    end
    
    puts "\nUpdated status:"
    user.reload
    puts "  - Photos this month: #{user.current_month_photos}"
    puts "  - Photo limit: #{user.effective_monthly_photo_limit}"
    puts "  - Can upload?: #{user.can_upload_photo?}"
    puts "  - Has active subscription?: #{user.has_active_subscription?}"
    puts "  - Can access pro features?: #{user.can_access_pro_features?}"
    
    puts "\n🎉 User #{user.email} can now upload photos!"
  end
  
  desc "List all users and their limits"
  task list_users: :environment do
    puts "All users:"
    User.includes(:subscriptions).each do |user|
      active_sub = user.subscriptions.active.first
      puts "#{user.email}:"
      puts "  - Photos: #{user.current_month_photos}/#{user.effective_monthly_photo_limit}"
      puts "  - Can upload: #{user.can_upload_photo?}"
      puts "  - Subscription: #{active_sub&.plan_id || 'none'} (#{active_sub&.status || 'inactive'})"
      puts
    end
  end
end