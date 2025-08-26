class UnsubscribeController < ApplicationController
  skip_before_action :authenticate
  
  def show
    @user = User.find_by(unsubscribe_token: params[:token])
    
    if @user
      @user.update(email_preferences: false)
      @success = true
    else
      @success = false
    end
  end
end