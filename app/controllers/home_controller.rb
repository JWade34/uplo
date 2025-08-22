class HomeController < ApplicationController
  allow_unauthenticated_access
  
  def index
    # Redirect authenticated users to dashboard
    if authenticated?
      redirect_to dashboard_path
    end
  end
end
