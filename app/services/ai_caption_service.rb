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
    
    generated_captions = []
    
    styles.each do |style|
      break unless @user.can_generate_caption? # Check again in case we've hit limit mid-generation
      
      caption_text = generate_caption_for_style(style)
      if caption_text.present?
        caption = @photo.captions.create!(
          content: caption_text,
          style: style,
          generated_at: Time.current
        )
        generated_captions << caption
        
        # Increment usage counter for each caption
        @user.increment_caption_usage!
      end
    end
    
    # Mark photo as processed
    @photo.update!(processed: true)
    
    generated_captions
  end
  
  private
  
  def generate_caption_for_style(style)
    prompt = build_prompt(style)
    image_url = get_image_url
    
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
      Rails.logger.error "OpenAI API error: #{e.message}"
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
    # OpenAI doesn't support HEIC files, so we need to convert them to JPEG first
    # and then encode as base64
    
    @photo.image.open do |file|
      service = ImageProcessingService.new(file)
      
      if service.send(:heic_file?)
        # For HEIC files, use the converted JPEG version
        service.send(:with_converted_image) do |converted_file|
          image_data = File.read(converted_file.path)
          base64_image = Base64.strict_encode64(image_data)
          return "data:image/jpeg;base64,#{base64_image}"
        end
      else
        # For other formats, use the original file
        image_data = file.read
        base64_image = Base64.strict_encode64(image_data)
        content_type = @photo.image.content_type
        return "data:#{content_type};base64,#{base64_image}"
      end
    end
  end
end