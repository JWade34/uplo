class Photo < ApplicationRecord
  belongs_to :user
  has_one_attached :image
  has_many_attached :social_variants # For storing different social media sizes
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
    image
  end

  # Get the display image URL for use in image_tag
  def display_image_url
    if heic_file?
      Rails.application.routes.url_helpers.display_heic_photo_path(self)
    else
      # Return the regular Active Storage URL for non-HEIC files
      Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true) if image.attached?
    end
  end
  
  # Check if the uploaded image is HEIC format
  def heic_file?
    return false unless image.attached?
    image.content_type.in?(['image/heic', 'image/heif'])
  end
  
  # Processing status helpers for UX
  def processing_duration
    return nil unless processing_started_at
    
    end_time = processed? ? updated_at : Time.current
    ((end_time - processing_started_at) / 1.minute).round(1)
  end
  
  def processing_elapsed_seconds
    return 0 unless processing_started_at
    
    end_time = processed? ? updated_at : Time.current
    (end_time - processing_started_at).to_i
  end
  
  def estimated_completion_time
    return nil if processed? || !processing_started_at
    
    # Estimate based on subscription tier
    estimated_seconds = user.can_access_pro_features? ? 8 : 5 # Pro users get 3 captions vs 1
    elapsed = processing_elapsed_seconds
    
    [estimated_seconds - elapsed, 0].max
  end
  
  def processing_progress_percentage
    return 100 if processed?
    return 0 unless processing_started_at
    
    estimated_total = user.can_access_pro_features? ? 8 : 5
    elapsed = processing_elapsed_seconds
    
    [(elapsed.to_f / estimated_total * 100).round, 95].min # Cap at 95% until actually done
  end
  
  # Social media variant management
  def generate_social_variants!
    return if social_variants.any? # Don't regenerate if they already exist
    
    image.open do |file|
      service = ImageProcessingService.new(file)
      variants = service.create_social_variants
      
      variants.each do |variant_name, variant_data|
        begin
          # Attach each variant with a descriptive filename
          social_variants.attach(
            io: variant_data[:file],
            filename: "#{filename&.split('.')&.first || id}_#{variant_name}.jpg",
            content_type: 'image/jpeg'
          )
          
          Rails.logger.info "Generated #{variant_name} variant: #{variant_data[:width]}x#{variant_data[:height]} (#{number_to_human_size(variant_data[:file_size])})"
        ensure
          # Clean up temporary file
          variant_data[:file].close
          variant_data[:file].unlink
        end
      end
      
      Rails.logger.info "Generated #{variants.count} social media variants for photo #{id}"
    end
  end
  
  # Get specific social media variant
  def social_variant(platform)
    return nil unless social_variants.any?
    
    # Find variant by filename pattern
    variant_name = case platform.to_s
    when 'instagram_square' then 'instagram_square'
    when 'instagram_portrait' then 'instagram_portrait'  
    when 'instagram_landscape' then 'instagram_landscape'
    when 'facebook' then 'facebook'
    when 'web_hq' then 'web_hq'
    else nil
    end
    
    return nil unless variant_name
    
    social_variants.find { |variant| variant.filename.to_s.include?(variant_name) }
  end
  
  # Get all available social variants
  def available_social_variants
    return [] unless social_variants.any?
    
    variants = []
    %w[instagram_square instagram_portrait instagram_landscape facebook web_hq].each do |variant_name|
      variant = social_variant(variant_name)
      if variant
        variants << {
          name: variant_name,
          display_name: variant_name.humanize,
          attachment: variant,
          dimensions: get_variant_dimensions(variant_name)
        }
      end
    end
    
    variants
  end
  
  private
  
  def get_variant_dimensions(variant_name)
    case variant_name
    when 'instagram_square' then '1080×1080'
    when 'instagram_portrait' then '1080×1350'
    when 'instagram_landscape' then '1080×566'
    when 'facebook' then '1200×630'
    when 'web_hq' then 'High Quality Web'
    else 'Unknown'
    end
  end
  
  def number_to_human_size(size)
    units = ['B', 'KB', 'MB', 'GB']
    unit = 0
    while size >= 1024 && unit < units.length - 1
      size /= 1024.0
      unit += 1
    end
    "%.1f %s" % [size, units[unit]]
  end
  
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
