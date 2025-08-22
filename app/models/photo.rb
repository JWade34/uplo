class Photo < ApplicationRecord
  belongs_to :user
  has_one_attached :image
  has_many :captions, dependent: :destroy
  has_many :post_performances, dependent: :destroy
  
  # Serialize metadata as JSON
  serialize :metadata, coder: JSON
  
  # Title is optional
  validates :image, presence: true
  validate :image_format
  
  scope :recent, -> { order(created_at: :desc) }
  scope :processed, -> { where(processed: true) }
  scope :unprocessed, -> { where(processed: false) }
  
  # Callbacks
  after_create :extract_metadata_async
  
  # Helper methods
  def metadata_summary
    return {} unless metadata.present?
    
    summary = {}
    
    # Device/Camera info
    if metadata['iphone_model']
      summary[:device] = "#{metadata['iphone_model']}"
      summary[:device] += " (iOS #{metadata['ios_version']})" if metadata['ios_version']
    elsif camera_info
      summary[:camera] = camera_info
    end
    
    # Technical settings
    summary[:settings] = camera_settings if camera_settings
    
    # Image properties
    if metadata['width'] && metadata['height']
      megapixels = (metadata['width'] * metadata['height'] / 1_000_000.0).round(1)
      summary[:resolution] = "#{metadata['width']}×#{metadata['height']} (#{megapixels}MP)"
    end
    
    # Location context
    if metadata['has_location']
      location_parts = []
      location_parts << metadata['location_context'] if metadata['location_context']
      location_parts << metadata['altitude_display'] if metadata['altitude_display']
      location_parts << "Indoors" if metadata['likely_indoor']
      location_parts << "Moving (#{metadata['movement_speed']})" if metadata['likely_in_motion']
      
      summary[:location] = location_parts.any? ? location_parts.join(', ') : 'GPS Available'
    end
    
    # Time context
    if date_taken
      hour = date_taken.hour
      time_of_day = case hour
      when 5..11 then "Morning"
      when 12..17 then "Afternoon"
      when 18..21 then "Evening" 
      else "Night"
      end
      summary[:taken_at] = "#{time_of_day}, #{date_taken.strftime('%b %d %Y')}"
    end
    
    # Shooting conditions
    shooting_details = []
    shooting_details << metadata['flash_mode'] if metadata['flash_mode']
    shooting_details << "#{metadata['exposure_mode']} mode" if metadata['exposure_mode']
    
    if shooting_details.any?
      summary[:conditions] = shooting_details.join(', ')
    end
    
    summary.compact
  end
  
  def camera_info
    return nil unless metadata['camera_make'] || metadata['camera_model']
    [metadata['camera_make'], metadata['camera_model']].compact.join(' ')
  end
  
  def camera_settings
    settings = []
    settings << "ISO #{metadata['iso']}" if metadata['iso']
    settings << "f/#{metadata['aperture']}" if metadata['aperture']
    settings << "#{metadata['shutter_speed']}" if metadata['shutter_speed']
    settings << "#{metadata['focal_length']}mm" if metadata['focal_length']
    settings.any? ? settings.join(', ') : nil
  end
  
  def image_dimensions
    return nil unless metadata['width'] && metadata['height']
    "#{metadata['width']}×#{metadata['height']}"
  end
  
  def location_info
    return nil unless metadata['has_location']
    'Location available'
  end
  
  def date_taken
    metadata['date_taken_original'] || metadata['date_taken']
  end
  
  def orientation_type
    metadata['orientation_type'] || 'unknown'
  end
  
  def aspect_ratio
    metadata['aspect_ratio']
  end
  
  # Generate context for AI from metadata
  def metadata_context
    ImageProcessingService.generate_context_from_metadata(metadata || {})
  end
  
  # Get browser-compatible image for display
  # Converts HEIC to JPEG for browsers that don't support HEIC
  def display_image
    return image unless heic_file?
    
    # For HEIC files, return a path to our custom conversion endpoint
    Rails.application.routes.url_helpers.display_heic_photo_path(self)
  end

  # Get the display image URL for use in image_tag
  def display_image_url
    if heic_file?
      Rails.application.routes.url_helpers.display_heic_photo_path(self)
    else
      image
    end
  end
  
  # Check if the uploaded image is HEIC format
  def heic_file?
    return false unless image.attached?
    image.content_type.in?(['image/heic', 'image/heif'])
  end
  
  private
  
  def image_format
    return unless image.attached?
    
    # Allow HEIC files along with standard formats
    allowed_types = [
      'image/jpeg', 'image/jpg', 'image/png', 'image/webp', 
      'image/heic', 'image/heif'
    ]
    
    unless image.content_type.in?(allowed_types)
      errors.add(:image, 'must be a JPEG, PNG, WebP, or HEIC image')
    end
    
    if image.byte_size > 10.megabytes
      errors.add(:image, 'must be less than 10MB')
    end
  end
  
  def extract_metadata_async
    # Extract metadata in a background job to avoid blocking upload
    MetadataExtractionJob.perform_later(id) if image.attached?
  end
end
