require 'mini_magick'
require 'exifr/jpeg'
require 'tempfile'

class ImageProcessingService
  def initialize(uploaded_file)
    @uploaded_file = uploaded_file
    @metadata = {}
  end

  def process
    # Convert HEIC to JPEG if needed and extract metadata
    with_converted_image do |processed_file|
      extract_metadata(processed_file)
      {
        processed_file: processed_file,
        metadata: @metadata,
        original_format: detect_format(@uploaded_file),
        needs_conversion: heic_file?
      }
    end
  end

  def self.extract_metadata_from_blob(blob)
    # Extract metadata from an ActiveStorage blob
    return {} unless blob.attached?

    begin
      blob.open do |file|
        service = new(file)
        service.extract_metadata(file)
        service.metadata
      end
    rescue => e
      Rails.logger.error "Failed to extract metadata: #{e.message}"
      {}
    end
  end

  def metadata
    @metadata
  end

  private

  def with_converted_image
    if heic_file?
      # Convert HEIC to JPEG
      converted_file = convert_heic_to_jpeg
      begin
        yield converted_file
      ensure
        converted_file.close
        converted_file.unlink
      end
    else
      # Use original file
      yield @uploaded_file
    end
  end

  def heic_file?
    detect_format(@uploaded_file).downcase.in?(['heic', 'heif'])
  end

  def detect_format(file)
    # Get file extension
    if file.respond_to?(:original_filename) && file.original_filename
      File.extname(file.original_filename).delete('.').downcase
    elsif file.respond_to?(:path)
      File.extname(file.path).delete('.').downcase
    else
      # Try to detect from content
      begin
        image = MiniMagick::Image.new(file.path)
        image.type.downcase
      rescue
        'unknown'
      end
    end
  end

  def convert_heic_to_jpeg
    temp_file = Tempfile.new(['converted', '.jpg'])
    
    begin
      # Use MiniMagick to convert HEIC to JPEG
      image = MiniMagick::Image.open(@uploaded_file.path)
      image.format 'jpeg'
      image.quality 90
      image.write temp_file.path
      
      temp_file.rewind
      temp_file
    rescue => e
      temp_file.close
      temp_file.unlink
      raise "HEIC conversion failed: #{e.message}"
    end
  end

  def extract_metadata(file)
    extract_exif_data(file)
    extract_image_properties(file)
    extract_location_data if @metadata[:gps_latitude] && @metadata[:gps_longitude]
  rescue => e
    Rails.logger.error "Metadata extraction failed: #{e.message}"
    @metadata[:extraction_error] = e.message
  end

  def extract_exif_data(file)
    # Try EXIFR first for detailed EXIF data
    begin
      if file.path.match?(/\.(jpe?g)$/i)
        exif = EXIFR::JPEG.new(file.path)
        if exif&.exif_data
          @metadata.merge!(extract_exif_fields(exif))
        end
      end
    rescue => e
      Rails.logger.warn "EXIFR extraction failed: #{e.message}"
    end

    # Fallback to MiniMagick for basic metadata
    begin
      image = MiniMagick::Image.open(file.path)
      @metadata.merge!(extract_minimagick_fields(image))
    rescue => e
      Rails.logger.warn "MiniMagick metadata extraction failed: #{e.message}"
    end
  end

  def extract_exif_fields(exif)
    fields = {}
    
    # Camera information
    fields[:camera_make] = exif.make&.strip
    fields[:camera_model] = exif.model&.strip
    fields[:lens_model] = exif.lens_model&.strip
    fields[:lens_make] = exif.lens_make&.strip if exif.respond_to?(:lens_make)
    fields[:software] = exif.software&.strip if exif.software
    
    # Shooting settings
    fields[:iso] = exif.iso
    fields[:aperture] = exif.f_number&.to_f
    fields[:shutter_speed] = exif.exposure_time&.to_s
    fields[:focal_length] = exif.focal_length&.to_f
    fields[:focal_length_35mm] = exif.focal_length_in35mm_film if exif.focal_length_in35mm_film
    
    # Exposure settings
    fields[:exposure_mode] = exif.exposure_mode if exif.exposure_mode
    fields[:exposure_program] = exif.exposure_program if exif.exposure_program
    fields[:exposure_bias] = exif.exposure_bias_value&.to_f if exif.exposure_bias_value
    fields[:metering_mode] = exif.metering_mode if exif.metering_mode
    fields[:white_balance] = exif.white_balance if exif.white_balance
    
    # Flash information
    fields[:flash] = exif.flash
    fields[:flash_mode] = parse_flash_mode(exif.flash) if exif.flash
    
    # Date and time information
    fields[:date_taken] = exif.date_time
    fields[:date_taken_original] = exif.date_time_original
    fields[:date_digitized] = exif.date_time_digitized if exif.date_time_digitized
    
    # GPS data and location
    if exif.gps&.longitude && exif.gps&.latitude
      fields[:gps_latitude] = exif.gps.latitude
      fields[:gps_longitude] = exif.gps.longitude
      fields[:gps_altitude] = exif.gps.altitude
      fields[:gps_speed] = exif.gps.speed if exif.gps.speed
      fields[:gps_direction] = exif.gps.img_direction if exif.gps.img_direction
      fields[:gps_timestamp] = exif.gps.date_stamp if exif.gps.date_stamp
    end
    
    # iPhone/Mobile specific data
    fields[:device_make] = exif.make&.strip if exif.make&.downcase&.include?('apple')
    if exif.model&.downcase&.include?('iphone')
      fields[:iphone_model] = exif.model&.strip
      fields[:ios_version] = exif.software&.strip if exif.software
    end
    
    # Image orientation and processing
    fields[:orientation] = exif.orientation
    fields[:compression] = exif.compression if exif.compression
    fields[:color_space] = exif.color_space if exif.color_space
    
    # Additional technical data
    fields[:scene_capture_type] = exif.scene_capture_type if exif.scene_capture_type
    fields[:subject_distance_range] = exif.subject_distance_range if exif.subject_distance_range
    fields[:digital_zoom_ratio] = exif.digital_zoom_ratio&.to_f if exif.digital_zoom_ratio
    
    # Artist/Creator information
    fields[:artist] = exif.artist&.strip if exif.artist
    fields[:copyright] = exif.copyright&.strip if exif.copyright
    
    fields.compact
  end

  def extract_minimagick_fields(image)
    fields = {}
    
    # Basic image properties
    fields[:width] = image.width
    fields[:height] = image.height
    fields[:format] = image.type.downcase
    fields[:file_size] = image.size
    
    # Resolution if available
    if image.resolution&.any?
      fields[:resolution] = "#{image.resolution.first}x#{image.resolution.last}"
    end
    
    # Color information
    fields[:colorspace] = image.colorspace if image.colorspace
    
    # Try to get quality if available
    begin
      fields[:quality] = image["%[quality]"].to_i if image["%[quality]"]
    rescue
      # Quality not available for this image format
    end
    
    fields.compact
  end

  def extract_image_properties(file)
    begin
      image = MiniMagick::Image.open(file.path)
      
      # Calculate aspect ratio
      if @metadata[:width] && @metadata[:height]
        @metadata[:aspect_ratio] = (@metadata[:width].to_f / @metadata[:height].to_f).round(2)
        @metadata[:orientation_type] = determine_orientation_type(@metadata[:width], @metadata[:height])
      end
      
      # Extract dominant colors (simplified)
      @metadata[:has_transparency] = image.alpha?
      
    rescue => e
      Rails.logger.warn "Image properties extraction failed: #{e.message}"
    end
  end

  def determine_orientation_type(width, height)
    ratio = width.to_f / height.to_f
    case ratio
    when 0..0.8 then 'portrait'
    when 0.8..1.2 then 'square'
    else 'landscape'
    end
  end

  def extract_location_data
    @metadata[:has_location] = true
    
    # Calculate location context
    lat = @metadata[:gps_latitude]
    lng = @metadata[:gps_longitude]
    
    if lat && lng
      # Add coordinate formatting
      @metadata[:gps_coordinates] = "#{lat.round(6)}, #{lng.round(6)}"
      
      # Determine general location context based on coordinates
      @metadata[:location_context] = determine_location_context(lat, lng)
      
      # Add altitude context if available
      if @metadata[:gps_altitude]
        altitude_m = @metadata[:gps_altitude]
        altitude_ft = (altitude_m * 3.28084).round(0)
        @metadata[:altitude_display] = "#{altitude_m.round(0)}m (#{altitude_ft}ft)"
        
        # Determine if it's indoor/outdoor based on altitude patterns
        @metadata[:likely_indoor] = indoor_detection_from_altitude(altitude_m)
      end
      
      # Speed context (if moving when photo was taken)
      if @metadata[:gps_speed] && @metadata[:gps_speed] > 0
        speed_kmh = @metadata[:gps_speed] * 3.6
        @metadata[:movement_speed] = "#{speed_kmh.round(1)} km/h"
        @metadata[:likely_in_motion] = speed_kmh > 5 # Walking speed threshold
      end
    end
  end
  
  def determine_location_context(lat, lng)
    # Basic geographic context based on coordinates
    case lat
    when 24..49 # Continental US latitude range
      case lng
      when -125..-66 # Continental US longitude range
        "Continental United States"
      else
        "North America"
      end
    when 49..72 # Canada
      "Canada"
    when -56..12 # South America
      "South America"
    when 36..71 # Europe
      "Europe"
    else
      "Unknown region"
    end
  rescue
    "Location available"
  end
  
  def indoor_detection_from_altitude(altitude)
    # Heuristic: if altitude is very precise or at common indoor levels
    # Most phones show very precise altitude indoors due to barometric pressure
    altitude_precision = altitude.to_s.split('.').last&.length || 0
    altitude_precision > 1 && altitude.between?(-100, 2000) # Reasonable indoor range
  end
  
  def parse_flash_mode(flash_value)
    return nil unless flash_value.is_a?(Integer)
    
    case flash_value & 0x07 # Extract flash fired bits
    when 0 then "No Flash"
    when 1 then "Flash Fired"
    when 5 then "Flash Fired, Return not detected"
    when 7 then "Flash Fired, Return detected"
    else "Flash Mode #{flash_value}"
    end
  rescue
    nil
  end

  private

  def create_variant(source_file, width, height, mode)
    temp_file = Tempfile.new(["variant_#{width}x#{height}", '.jpg'])
    
    begin
      image = MiniMagick::Image.open(source_file.path)
      
      case mode
      when :crop
        # Crop to exact dimensions (center crop)
        image.resize "#{width}x#{height}^"
        image.gravity 'center'
        image.crop "#{width}x#{height}+0+0"
      when :fit
        # Fit within dimensions (maintain aspect ratio, may have padding)
        image.resize "#{width}x#{height}"
      when :resize
        # Resize with max dimension constraint
        image.resize "#{width}x#{height}>"
      end
      
      # High quality JPEG for social media
      image.format 'jpeg'
      image.quality 92
      image.strip
      
      image.write temp_file.path
      temp_file.rewind
      
      {
        file: temp_file,
        width: image.width,
        height: image.height, 
        file_size: File.size(temp_file.path),
        mode: mode
      }
    rescue => e
      temp_file.close
      temp_file.unlink
      raise "Variant creation failed: #{e.message}"
    end
  end

  public

  # Create optimized version for AI processing (smaller, faster)
  def create_ai_optimized_version
    with_converted_image do |processed_file|
      temp_file = Tempfile.new(['ai_optimized', '.jpg'])
      
      begin
        image = MiniMagick::Image.open(processed_file.path)
        
        # Resize to max 1200px on longest side while maintaining aspect ratio
        image.resize "1200x1200>"
        
        # Set JPEG quality to 85% for good balance of quality vs size
        image.format 'jpeg'
        image.quality 85
        
        # Remove unnecessary metadata to reduce file size
        image.strip
        
        image.write temp_file.path
        temp_file.rewind
        
        {
          file: temp_file,
          width: image.width,
          height: image.height,
          file_size: File.size(temp_file.path)
        }
      rescue => e
        temp_file.close
        temp_file.unlink
        raise "AI optimization failed: #{e.message}"
      end
    end
  end

  # Create social media optimized variants
  def create_social_variants
    variants = {}
    
    with_converted_image do |processed_file|
      # Instagram Square (1080x1080)
      variants[:instagram_square] = create_variant(processed_file, 1080, 1080, :crop)
      
      # Instagram Portrait (1080x1350)
      variants[:instagram_portrait] = create_variant(processed_file, 1080, 1350, :fit)
      
      # Instagram Landscape (1080x566)  
      variants[:instagram_landscape] = create_variant(processed_file, 1080, 566, :fit)
      
      # Facebook Recommended (1200x630)
      variants[:facebook] = create_variant(processed_file, 1200, 630, :fit)
      
      # High Quality Web (1920px max width)
      variants[:web_hq] = create_variant(processed_file, 1920, 1920, :resize)
    end
    
    variants
  end

  # Helper method to generate context for AI caption generation
  def self.generate_context_from_metadata(metadata)
    context_parts = []
    
    # Device and camera information
    if metadata[:iphone_model]
      context_parts << "Shot on #{metadata[:iphone_model]}"
      context_parts << "iOS #{metadata[:ios_version]}" if metadata[:ios_version]
    elsif metadata[:camera_make] && metadata[:camera_model]
      context_parts << "Photo taken with #{metadata[:camera_make]} #{metadata[:camera_model]}"
    end
    
    # Lens information
    if metadata[:lens_model]
      context_parts << "Using #{metadata[:lens_model]} lens"
    end
    
    # Shooting conditions and settings
    technical_details = []
    technical_details << "ISO #{metadata[:iso]}" if metadata[:iso]
    technical_details << "f/#{metadata[:aperture]}" if metadata[:aperture]
    technical_details << "#{metadata[:shutter_speed]}s" if metadata[:shutter_speed]
    technical_details << "#{metadata[:focal_length]}mm" if metadata[:focal_length]
    technical_details << "#{metadata[:focal_length_35mm]}mm equivalent" if metadata[:focal_length_35mm]
    
    if technical_details.any?
      context_parts << "Camera settings: #{technical_details.join(', ')}"
    end
    
    # Exposure and shooting mode context
    exposure_info = []
    exposure_info << metadata[:flash_mode] if metadata[:flash_mode]
    exposure_info << "#{metadata[:exposure_mode]} mode" if metadata[:exposure_mode]
    exposure_info << "#{metadata[:white_balance]} white balance" if metadata[:white_balance]
    
    if exposure_info.any?
      context_parts << "Shooting details: #{exposure_info.join(', ')}"
    end
    
    # Image characteristics
    if metadata[:orientation_type]
      context_parts << "#{metadata[:orientation_type].capitalize} orientation"
    end
    
    if metadata[:width] && metadata[:height]
      megapixels = (metadata[:width] * metadata[:height] / 1_000_000.0).round(1)
      context_parts << "#{metadata[:width]}×#{metadata[:height]} resolution (#{megapixels}MP)"
    end
    
    # Time and temporal context
    if metadata[:date_taken_original]
      taken_time = metadata[:date_taken_original]
      hour = taken_time.hour
      
      time_context = case hour
      when 5..11 then "morning"
      when 12..17 then "afternoon" 
      when 18..21 then "evening"
      else "night"
      end
      
      context_parts << "Taken in the #{time_context} on #{taken_time.strftime('%B %d, %Y')}"
    end
    
    # Location and environmental context
    if metadata[:has_location]
      location_details = []
      location_details << metadata[:location_context] if metadata[:location_context]
      location_details << metadata[:altitude_display] if metadata[:altitude_display]
      
      if metadata[:likely_indoor]
        location_details << "likely indoors"
      elsif metadata[:gps_altitude] && metadata[:gps_altitude] > 100
        location_details << "elevated location"
      end
      
      if metadata[:likely_in_motion]
        location_details << "taken while moving (#{metadata[:movement_speed]})"
      end
      
      if location_details.any?
        context_parts << "Location: #{location_details.join(', ')}"
      else
        context_parts << "Location data available"
      end
    end
    
    # Image quality and technical context
    quality_details = []
    if metadata[:quality] && metadata[:quality] > 90
      quality_details << "high quality"
    elsif metadata[:quality] && metadata[:quality] < 70
      quality_details << "compressed"
    end
    
    if metadata[:digital_zoom_ratio] && metadata[:digital_zoom_ratio] > 1
      quality_details << "#{metadata[:digital_zoom_ratio]}x digital zoom used"
    end
    
    if quality_details.any?
      context_parts << "Image quality: #{quality_details.join(', ')}"
    end
    
    context_parts.join('. ') + '.' if context_parts.any?
  end

  # Create a display-optimized version for faster loading
  def create_display_optimized_version
    with_converted_image do |processed_file|
      temp_file = Tempfile.new(['display_optimized', '.jpg'])
      
      begin
        image = MiniMagick::Image.open(processed_file.path)
        
        # Resize for web display - larger than AI version but smaller than original
        image.resize "800x800>"
        image.format 'jpeg'
        image.quality 90
        image.strip # Remove all metadata
        
        image.write(temp_file.path)
        
        # Attach as a variant to the photo
        if @uploaded_file.respond_to?(:attach) # ActiveStorage blob
          @uploaded_file.variant(resize_to_limit: [800, 800], format: :jpeg, quality: 90)
        end
        
        Rails.logger.info "Display optimized version created successfully"
        temp_file.path
      ensure
        temp_file.close
      end
    end
  rescue => e
    Rails.logger.error "Failed to create display optimized version: #{e.message}"
    raise e
  end
end