class OnboardingController < ApplicationController
  before_action :require_authentication
  before_action :redirect_if_onboarding_complete, except: [:complete]
  
  def index
    redirect_to onboarding_welcome_path
  end

  def welcome
    # Step 1: Welcome and explanation
  end

  def profile
    # Step 2: Collect profile information
    @user = Current.user
  end
  
  def update_profile
    @user = Current.user
    
    if @user.update(profile_params)
      # Don't mark as complete yet - give option for advanced setup
      redirect_to onboarding_advanced_path
    else
      render :profile, status: :unprocessable_entity
    end
  end
  
  def advanced
    # Step 3: Advanced profile information (optional)
    @user = Current.user
  end
  
  def update_advanced
    @user = Current.user
    
    if @user.update(advanced_params)
      @user.update!(onboarding_completed: true)
      redirect_to onboarding_complete_path
    else
      render :advanced, status: :unprocessable_entity
    end
  end

  def complete
    # Mark as complete if they skipped advanced setup
    unless Current.user.onboarding_completed?
      Current.user.update!(onboarding_completed: true)
    end
  end
  
  private
  
  def redirect_if_onboarding_complete
    redirect_to dashboard_path if Current.user.onboarding_completed?
  end
  
  def profile_params
    params.require(:user).permit(:bio, :fitness_focus, :target_audience, :tone_preference, :business_type)
  end
  
  def advanced_params
    params.require(:user).permit(:client_pain_points, :unique_approach, :brand_personality, :sample_caption, 
                                 :call_to_action_preference, :location, :price_range, :posting_frequency, 
                                 :favorite_hashtags, :words_to_avoid)
  end
end
