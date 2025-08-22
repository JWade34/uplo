class ProfileController < ApplicationController
  before_action :require_authentication
  before_action :set_user
  
  def show
    # Profile overview page
  end

  def edit
    # Profile edit form
  end

  def update
    puts "UPDATE ACTION CALLED"
    
    if @user.update(profile_params)
      redirect_to profile_path, notice: 'Profile updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_user
    @user = Current.user
  end
  
  def profile_params
    params.require(:user).permit(
      :email_address, :password, :password_confirmation, :profile_picture,
      :bio, :fitness_focus, :target_audience, :tone_preference, :business_type,
      :client_pain_points, :unique_approach, :brand_personality, :sample_caption,
      :call_to_action_preference, :location, :price_range, :posting_frequency,
      :favorite_hashtags, :words_to_avoid
    )
  end
end
