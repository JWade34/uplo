class PhotoProcessingJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(photo_id)
    photo = Photo.find(photo_id)
    
    Rails.logger.info "Starting AI caption generation for photo #{photo.id}"
    
    service = AiCaptionService.new(photo)
    captions = service.generate_captions
    
    if captions.any?
      Rails.logger.info "Generated #{captions.count} captions for photo #{photo.id}"
    else
      Rails.logger.error "Failed to generate captions for photo #{photo.id}"
    end
    
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Photo with ID #{photo_id} not found"
  rescue => e
    Rails.logger.error "Error processing photo #{photo_id}: #{e.message}"
    raise e  # This will trigger the retry mechanism
  end
end
