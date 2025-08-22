# Analytics Mock Data Generator
# This file generates realistic performance data for dashboard demonstration

class AnalyticsDataGenerator
  PLATFORMS = %w[instagram facebook tiktok linkedin twitter].freeze
  
  def self.generate_for_user(user, num_posts: 25)
    puts "Generating mock analytics data for #{user.email_address}..."
    
    # Clear existing data
    user.photos.joins(:post_performances).destroy_all
    user.analytics_summaries.destroy_all
    
    # Generate photos with performance data
    photos_with_performance = []
    
    num_posts.times do |i|
      # Create photo (skip image validation for mock data)
      photo = user.photos.new(
        title: "Workout Session ##{i + 1}",
        description: sample_descriptions.sample,
        processed: true,
        created_at: rand(90.days.ago..Time.current)
      )
      photo.save!(validate: false)
      
      # Create caption
      photo.captions.create!(
        content: sample_captions.sample,
        style: ['motivational', 'educational', 'friendly'].sample,
        generated_at: photo.created_at + rand(1..30).minutes
      )
      
      # Create performance data for 1-3 platforms
      platforms_for_post = PLATFORMS.sample(rand(1..3))
      
      platforms_for_post.each do |platform|
        engagement_rate = generate_engagement_rate(user.subscription_tier, platform)
        reach = generate_reach(platform)
        likes = (reach * engagement_rate / 100 * rand(0.6..0.8)).to_i
        comments = (likes * rand(0.05..0.15)).to_i
        shares = (likes * rand(0.02..0.08)).to_i
        
        performance = photo.post_performances.create!(
          platform: platform,
          likes: likes,
          comments: comments,
          shares: shares,
          reach: reach,
          engagement_rate: engagement_rate,
          posted_at: photo.created_at + rand(30.minutes..2.hours)
        )
        
        photos_with_performance << { photo: photo, performance: performance }
      end
    end
    
    # Generate monthly analytics summaries
    generate_monthly_summaries(user, photos_with_performance)
    
    puts "Generated #{num_posts} photos with performance data"
    puts "Generated #{user.photos.joins(:post_performances).count} total platform posts"
  end
  
  private
  
  def self.generate_engagement_rate(tier, platform)
    base_rates = {
      'instagram' => { starter: 2.5, pro: 4.2, enterprise: 6.1 },
      'facebook' => { starter: 1.8, pro: 3.1, enterprise: 4.8 },
      'tiktok' => { starter: 3.2, pro: 5.4, enterprise: 7.9 },
      'linkedin' => { starter: 1.5, pro: 2.8, enterprise: 4.2 },
      'twitter' => { starter: 1.2, pro: 2.1, enterprise: 3.5 }
    }
    
    base = base_rates[platform][tier.to_sym]
    # Add randomness: ±30% variation
    base * rand(0.7..1.3)
  end
  
  def self.generate_reach(platform)
    base_reach = {
      'instagram' => 1500,
      'facebook' => 800,
      'tiktok' => 2500,
      'linkedin' => 600,
      'twitter' => 400
    }
    
    # Add significant variation: 50% to 300% of base
    (base_reach[platform] * rand(0.5..3.0)).to_i
  end
  
  def self.generate_monthly_summaries(user, photos_with_performance)
    # Generate summaries for last 3 months
    3.times do |month_offset|
      period_end = month_offset.months.ago.end_of_month.to_date
      period_start = period_end.beginning_of_month
      
      # Get photos from this period
      period_photos = photos_with_performance.select do |data|
        data[:performance].posted_at.to_date.between?(period_start, period_end)
      end
      
      next if period_photos.empty?
      
      # Calculate metrics
      performances = period_photos.map { |data| data[:performance] }
      avg_engagement = performances.sum(&:engagement_rate) / performances.count
      best_performance = performances.max_by(&:engagement_rate)
      best_photo = period_photos.find { |data| data[:performance] == best_performance }[:photo]
      
      # Simulate followers gained (higher for pro users)
      base_followers = user.pro? ? rand(25..60) : rand(8..25)
      followers_gained = (base_followers * (avg_engagement / 3.0)).to_i
      
      user.analytics_summaries.create!(
        total_posts: period_photos.count,
        avg_engagement_rate: avg_engagement.round(2),
        best_performing_post: best_photo,
        followers_gained: followers_gained,
        period_start: period_start,
        period_end: period_end,
        tier_at_time: user.subscription_tier
      )
    end
  end
  
  def self.sample_descriptions
    [
      "Morning strength training session focusing on compound movements",
      "HIIT cardio workout to boost metabolism and endurance", 
      "Functional movement patterns for everyday strength",
      "Core stability and balance training",
      "Upper body hypertrophy workout with progressive overload",
      "Lower body power development session",
      "Recovery and mobility focused training day",
      "Full body circuit training for fat loss",
      "Olympic lifting technique practice",
      "Bodyweight workout - no equipment needed"
    ]
  end
  
  def self.sample_captions
    [
      "💪 Another day, another opportunity to get stronger! What's your favorite exercise to challenge yourself? Drop it in the comments! #FitnessMotivation #StrengthTraining #PersonalTrainer",
      
      "🔥 Form over ego, always! Here's a reminder that proper technique beats heavy weight every time. Your future self will thank you for prioritizing safety and effectiveness. #FormMatters #SmartTraining #FitnessEducation",
      
      "⚡ High-intensity intervals are a game-changer for busy schedules! Just 20 minutes can deliver incredible results when you're consistent. Who's ready to push their limits today? #HIIT #TimeEfficient #BusyLifestyle",
      
      "🎯 Goal setting isn't just about the destination - it's about who you become on the journey. Every rep, every set, every choice shapes the person you're becoming. #MindsetMatters #FitnessGoals #PersonalGrowth",
      
      "🏋️‍♀️ Compound movements like this are your best friend for building functional strength. They work multiple muscle groups and translate to real-world activities. #CompoundMovements #FunctionalFitness #StrengthBuilding",
      
      "🌟 Consistency beats perfection every single time. You don't need to be perfect - you just need to show up and give your best effort today. #ConsistencyWins #ProgressOverPerfection #DailyHabits",
      
      "🔥 Your body is capable of amazing things when you fuel it right and train it smart. Trust the process and celebrate every small victory along the way! #TrustTheProcess #SmallWins #FitnessJourney",
      
      "💡 Did you know that strength training can boost your metabolism for up to 24 hours after your workout? That's the power of the afterburn effect! #FitnessEducation #Metabolism #StrengthTraining #ScienceBased"
    ]
  end
end

# Generate data for all users
User.all.each do |user|
  # Set trial end dates for existing users
  user.update!(trial_ends_at: 7.days.from_now) unless user.trial_ends_at
  
  # Generate different amounts of data based on subscription tier
  post_count = user.pro? ? 30 : 15
  AnalyticsDataGenerator.generate_for_user(user, num_posts: post_count)
end

puts "✅ Analytics mock data generation complete!"
puts "Users with data: #{User.joins(:photos).distinct.count}"
puts "Total photos: #{Photo.count}"
puts "Total performances: #{PostPerformance.count}"
puts "Total summaries: #{AnalyticsSummary.count}"