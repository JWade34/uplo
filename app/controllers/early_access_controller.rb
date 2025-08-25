class EarlyAccessController < ApplicationController
  allow_unauthenticated_access
  
  def index
    @signup = EarlyAccessSignup.new
  end

  def create
    @signup = EarlyAccessSignup.new(signup_params)
    create_account = params[:early_access_signup][:create_account] == '1'
    password = params[:early_access_signup][:password]
    
    if @signup.save
      # Create user account if requested
      if create_account && password.present?
        user = User.create(
          email_address: @signup.email,
          password: password
        )
        
        if user.persisted?
          session = user.sessions.create!(
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )
          Current.session = session
          
          flash[:notice] = "Welcome to Uplo! Your account has been created."
          redirect_to dashboard_path and return
        else
          flash.now[:alert] = "There was an error creating your account. Please try again."
          render :index, status: :unprocessable_entity and return
        end
      end
      
      # Send confirmation emails
      flash[:notice] = "Thanks for signing up! Check your email for next steps."
      
      begin
        EarlyAccessMailer.admin_notification(@signup).deliver_later
        EarlyAccessMailer.user_confirmation(@signup).deliver_later
      rescue => e
        Rails.logger.error "Email delivery failed: #{e.message}"
        # Don't fail the signup if email fails
      end
      
      redirect_to early_access_path
    else
      flash.now[:alert] = "Please fix the errors below."
      render :index, status: :unprocessable_entity
    end
  end

  private

  def signup_params
    params.require(:early_access_signup).permit(:name, :email, :business_type, :current_challenge, :marketing_emails)
  end
end
