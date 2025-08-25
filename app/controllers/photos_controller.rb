class PhotosController < ApplicationController
  before_action :require_authentication
  before_action :redirect_to_onboarding_if_needed, except: [:display_heic]
  before_action :set_photo, only: [:show, :display_heic]
  
  def index
    @photos = Current.user.photos.recent.includes(:image_attachment)
  end

  def new
    @photo = Current.user.photos.build
    @user = Current.user
    @user.reset_monthly_usage_if_needed
  end

  def create
    @user = Current.user
    @user.reset_monthly_usage_if_needed
    
    # Use enhanced usage monitoring
    usage_monitor = UsageMonitoringService.new(@user)
    
    unless usage_monitor.can_upload_photo?
      @photo = @user.photos.build(photo_params)
      
      if @user.can_access_pro_features?
        warning_message = usage_monitor.usage_warning_message || "You've reached your usage limit. Please contact support if you need additional capacity."
        @photo.errors.add(:base, warning_message)
      else
        @photo.errors.add(:base, "You've used all 5 trial photos. Upgrade to Pro for professional-grade processing with 250 photos per month!")
      end
      render :new, status: :unprocessable_entity
      return
    end
    
    @photo = @user.photos.build(photo_params)
    
    if @photo.save
      # Increment photo usage counter and daily tracking
      @user.increment_photo_usage!
      usage_monitor.increment_daily_usage!
      
      # Check and send usage warnings
      usage_monitor.check_monthly_usage_and_warn
      
      # Populate metadata from the uploaded file
      if @photo.image.attached?
        @photo.update!(
          filename: @photo.image.filename.to_s,
          content_type: @photo.image.content_type,
          file_size: @photo.image.byte_size
        )
        
        # Image optimization will be handled in the background job for better performance
        
        # Enqueue background job to generate AI captions
        PhotoProcessingJob.perform_later(@photo.id)
        
        # Set processing start time for better UX
        @photo.update!(processing_started_at: Time.current)
      end
      
      redirect_to @photo, notice: 'Photo uploaded successfully! Our AI is analyzing your image and generating personalized captions...'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @user = Current.user
    # Load captions with proper ordering
    @photo.captions.reload if @photo.captions.loaded?
  end

  def display_heic
    @photo = Current.user.photos.find(params[:id])
    
    if @photo.heic_file? && @photo.image.attached?
      # Use our ImageProcessingService to convert HEIC to JPEG
      @photo.image.open do |file|
        service = ImageProcessingService.new(file)
        if service.send(:heic_file?)
          service.send(:with_converted_image) do |converted_file|
            send_data File.read(converted_file.path),
                     type: 'image/jpeg',
                     disposition: 'inline',
                     filename: "#{@photo.title || 'photo'}.jpg"
          end
        end
      end
    else
      redirect_to @photo
    end
  end
  
  private
  
  def redirect_to_onboarding_if_needed
    redirect_to onboarding_path if Current.user.needs_onboarding?
  end
  
  def set_photo
    @photo = Current.user.photos.find(params[:id])
  end
  
  def photo_params
    params.require(:photo).permit(:title, :description, :image)
  end
end
