class PricingController < ApplicationController
  # Allow both authenticated and unauthenticated users to view pricing
  skip_before_action :require_authentication, only: [:index]
  
  def index
    @user = Current.user
    @current_plan = @user&.subscription_display_name || 'Free'
    @has_active_subscription = @user&.has_active_subscription?
    
    # Calculate potential savings for annual plan
    @monthly_price = 39
    @yearly_price = 390
    @yearly_savings = (@monthly_price * 12) - @yearly_price
    
    # Load testimonials and social proof
    @testimonials = load_testimonials
    @total_users = 527 # Update this with actual count in production
    @average_time_saved = "2.5 hours/week"
    @engagement_increase = "3.2x"
  end
  
  private
  
  def load_testimonials
    [
      {
        name: "Sarah Johnson",
        role: "Personal Trainer, FitLife Gym",
        image: "testimonial-1.jpg",
        content: "Uplo transformed my social media game. I went from spending hours creating content to just minutes. My engagement is up 300% and I've gained 15 new clients!",
        rating: 5
      },
      {
        name: "Mike Chen",
        role: "CrossFit Coach",
        image: "testimonial-2.jpg",
        content: "The AI captions are spot-on with my voice. It's like having a personal social media manager. Best investment for my business growth.",
        rating: 5
      },
      {
        name: "Jessica Martinez",
        role: "Yoga Instructor",
        image: "testimonial-3.jpg",
        content: "I was skeptical about AI-generated content, but Uplo learns my style perfectly. My followers love the consistency and I love the time I save.",
        rating: 5
      }
    ]
  end
end