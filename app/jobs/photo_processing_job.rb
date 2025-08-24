class PhotoProcessingJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(photo_id)
    photo = Photo.find(photo_id)
    
    Rails.logger.info "Starting photo processing for photo #{photo.id}"
    processing_start = Time.current
    
    # Generate AI captions
    Rails.logger.info "Generating AI captions..."
    service = AiCaptionService.new(photo)
    captions = service.generate_captions
    
    if captions.any?
      Rails.logger.info "Generated #{captions.count} captions for photo #{photo.id}"
    else
      Rails.logger.error "Failed to generate captions for photo #{photo.id}"
    end
    
    # Generate social media variants (background task to not slow down caption generation)
    Rails.logger.info "Generating social media variants..."
    begin
      photo.generate_social_variants!
      Rails.logger.info "Social media variants generated successfully"
    rescue => e
      Rails.logger.error "Failed to generate social variants: #{e.message}"
      # Don't fail the whole job if variants fail
    end
    
    processing_time = (Time.current - processing_start).round(2)
    Rails.logger.info "Completed photo processing for #{photo.id} in #{processing_time}s"
    
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Photo with ID #{photo_id} not found"
  rescue => e
    Rails.logger.error "Error processing photo #{photo_id}: #{e.message}"
    raise e  # This will trigger the retry mechanism
  end
end
