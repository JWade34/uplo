require 'base64'

class AiCaptionService
  include Rails.application.routes.url_helpers
  
  def initialize(photo)
    @photo = photo
    @user = photo.user
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end
  
  def generate_captions
    return false unless @photo.image.attached?
    return false unless @user.can_generate_caption?
    
    # Determine caption styles based on subscription tier
    styles = if @user.can_access_pro_features?
      ['motivational', 'educational', 'friendly'] # 3 styles for Pro users
    else
      ['friendly'] # 1 style for Starter users
    end
    
    # Pre-generate the image URL once for all API calls
    image_url = get_image_url
    generated_captions = []
    
    Rails.logger.info "Starting parallel AI caption generation for #{styles.count} styles"
    start_time = Time.current
    
    # Process all styles in parallel using threads
    caption_futures = styles.map do |style|
      Thread.new do
        begin
          next unless @user.can_generate_caption?
          
          Rails.logger.info "Generating #{style} caption..."
          caption_text = generate_caption_for_style_with_url(style, image_url)
          
          if caption_text.present?
            # Thread-safe caption creation
            caption = nil
            ActiveRecord::Base.connection_pool.with_connection do
              caption = @photo.captions.create!(
                content: caption_text,
                style: style,
                generated_at: Time.current
              )
              # Increment usage counter for each caption
              @user.increment_caption_usage!
            end
            Rails.logger.info "Generated #{style} caption (#{caption_text.length} chars)"
            caption
          end
        rescue => e
          Rails.logger.error "Error generating #{style} caption: #{e.message}"
          nil
        end
      end
    end
    
    # Wait for all threads to complete and collect results
    caption_futures.each do |future|
      caption = future.value # This blocks until the thread completes
      generated_captions << caption if caption
    end
    
    processing_time = (Time.current - start_time).round(2)
    Rails.logger.info "Completed AI caption generation in #{processing_time}s (#{generated_captions.count}/#{styles.count} successful)"
    
    # Mark photo as processed
    @photo.update!(processed: true)
    
    generated_captions
  end
  
  private
  
  def generate_caption_for_style(style)
    image_url = get_image_url
    generate_caption_for_style_with_url(style, image_url)
  end
  
  def generate_caption_for_style_with_url(style, image_url)
    prompt = build_prompt(style)
    
    begin
      response = @client.chat(
        parameters: {
          model: "gpt-4o",  # GPT-4 with vision
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "text",
                  text: prompt
                },
                {
                  type: "image_url",
                  image_url: {
                    url: image_url
                  }
                }
              ]
            }
          ],
          max_tokens: 300,
          temperature: 0.7
        }
      )
      
      response.dig("choices", 0, "message", "content")
    rescue => e
      Rails.logger.error "OpenAI API error for #{style}: #{e.message}"
      nil
    end
  end
  
  def build_prompt(style)
    base_context = build_user_context
    style_instructions = get_style_instructions(style)
    
    <<~PROMPT
      You are an expert fitness social media content creator. Analyze this gym/fitness photo and create an engaging Instagram caption.
      
      #{base_context}
      
      #{style_instructions}
      
      Requirements:
      - Caption should be #{style} in tone
      - Include 3-5 relevant hashtags (use the user's favorites if provided)
      - Keep it under 150 words
      - Make it specific to what you see in the image
      - Avoid generic fitness platitudes
      - Include a clear call-to-action related to the user's business
      #{@user.words_to_avoid.present? ? "- Avoid these words/phrases: #{@user.words_to_avoid}" : ""}
      
      Photo context: Title: "#{@photo.title}"#{@photo.description.present? ? ", Description: \"#{@photo.description}\"" : ""}
      
      Return ONLY the caption text, no additional commentary.
    PROMPT
  end
  
  def build_user_context
    context = []
    
    # User profile context
    if @user.bio.present?
      context << "Trainer Bio: #{@user.bio}"
    end
    
    if @user.fitness_focus.present?
      context << "Fitness Focus: #{@user.fitness_focus.humanize}"
    end
    
    if @user.target_audience.present?
      context << "Target Audience: #{@user.target_audience.humanize}"
    end
    
    if @user.business_type.present?
      context << "Business Type: #{@user.business_type.humanize}"
    end
    
    if @user.unique_approach.present?
      context << "Unique Approach: #{@user.unique_approach}"
    end
    
    if @user.brand_personality.present?
      context << "Brand Personality: #{@user.brand_personality}"
    end
    
    if @user.client_pain_points.present?
      context << "Client Pain Points to Address: #{@user.client_pain_points}"
    end
    
    if @user.call_to_action_preference.present?
      context << "Preferred Call-to-Action: #{@user.call_to_action_preference}"
    end
    
    if @user.location.present?
      context << "Location: #{@user.location}"
    end
    
    # Photo metadata context - this is the new addition
    metadata_context = @photo.metadata_context
    if metadata_context.present?
      context << "Photo Technical Details: #{metadata_context}"
    end
    
    context.join("\n")
  end
  
  def get_style_instructions(style)
    case style
    when 'motivational'
      "Create a motivational caption that inspires action and pushes people to overcome challenges. Use energetic language and focus on transformation and achievement."
    when 'educational'
      "Create an educational caption that teaches something valuable about the exercise, technique, or fitness concept shown. Share knowledge and insights."
    when 'friendly'
      "Create a friendly, conversational caption that feels like advice from a supportive friend. Use warm, approachable language and maybe share a personal insight."
    else
      "Create an engaging caption that matches the #{style} tone."
    end
  end
  
  def get_image_url
    # Use AI-optimized version for faster processing and smaller payloads
    @photo.image.open do |file|
      service = ImageProcessingService.new(file)
      
      # Create AI-optimized version (max 1200px, 85% quality)
      optimized = service.create_ai_optimized_version
      
      begin
        image_data = File.read(optimized[:file].path)
        base64_image = Base64.strict_encode64(image_data)
        
        Rails.logger.info "AI Processing: Optimized image from original to #{number_to_human_size(optimized[:file_size])} (#{optimized[:width]}x#{optimized[:height]})"
        
        return "data:image/jpeg;base64,#{base64_image}"
      ensure
        # Clean up temporary file
        optimized[:file].close
        optimized[:file].unlink
      end
    end
  end
  
  private
  
  def number_to_human_size(size)
    units = ['B', 'KB', 'MB', 'GB']
    unit = 0
    while size >= 1024 && unit < units.length - 1
      size /= 1024.0
      unit += 1
    end
    "%.1f %s" % [size, units[unit]]
  end
end