class MetadataExtractionJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(photo_id)
    photo = Photo.find(photo_id)
    return unless photo.image.attached?

    Rails.logger.info "Extracting metadata for photo #{photo.id}"

    begin
      # Download the image temporarily for processing
      photo.image.open do |file|
        # Create service instance and process the image
        service = ImageProcessingService.new(file)
        result = service.process
        
        # Store the extracted metadata
        photo.update!(metadata: result[:metadata])
        
        # Log success
        Rails.logger.info "Successfully extracted metadata for photo #{photo.id}: #{result[:metadata].keys.join(', ')}"
        
        # If it was a HEIC file that needed conversion, log that too
        if result[:needs_conversion]
          Rails.logger.info "Converted HEIC file for photo #{photo.id}"
        end
        
      rescue => e
        Rails.logger.error "Failed to extract metadata for photo #{photo.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Store error information in metadata
        photo.update!(metadata: { 
          extraction_error: e.message,
          extraction_attempted_at: Time.current 
        })
        
        raise e # Re-raise to trigger retry logic
      end
    rescue => e
      Rails.logger.error "Metadata extraction job failed for photo #{photo.id}: #{e.message}"
      # Don't re-raise here to prevent infinite retries
    end
  end
end
