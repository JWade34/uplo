module SeoHelper
  def page_title(title = nil)
    if title
      "#{title} | Uplo"
    else
      content_for(:title) || "Uplo - AI-Powered Social Media for Personal Trainers"
    end
  end

  def page_description(description = nil)
    description || content_for(:description) || "Transform your gym photos into engaging social media content that attracts more clients. Join 500+ personal trainers using AI-powered caption generation."
  end

  def page_keywords(keywords = nil)
    keywords || content_for(:keywords) || "personal trainer social media, fitness social media, AI caption generator, gym social media, fitness marketing, personal trainer marketing"
  end

  def og_image_url(image = nil)
    if image
      asset_url(image)
    elsif content_for(:og_image)
      content_for(:og_image)
    else
      asset_url('uplo-og-image.svg')
    end
  end

  def canonical_url
    content_for(:canonical_url) || request.original_url
  end

  def structured_data_for_page(page_type = nil)
    case page_type
    when 'home'
      home_page_structured_data
    when 'early_access'
      early_access_structured_data
    when 'dashboard'
      dashboard_structured_data
    else
      default_structured_data
    end
  end

  private

  def home_page_structured_data
    {
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "Uplo",
      "url" => request.base_url,
      "description" => "AI-powered social media content creation for personal trainers",
      "potentialAction" => {
        "@type" => "SearchAction",
        "target" => "#{request.base_url}/?q={search_term_string}",
        "query-input" => "required name=search_term_string"
      }
    }
  end

  def early_access_structured_data
    {
      "@context" => "https://schema.org",
      "@type" => "WebPage",
      "name" => "Early Access - Uplo",
      "description" => "Get early access to Uplo's AI-powered social media tools",
      "url" => request.original_url
    }
  end

  def dashboard_structured_data
    {
      "@context" => "https://schema.org",
      "@type" => "WebApplication",
      "name" => "Uplo Dashboard",
      "applicationCategory" => "BusinessApplication",
      "description" => "Performance dashboard for AI-generated social media content"
    }
  end

  def default_structured_data
    {
      "@context" => "https://schema.org",
      "@type" => "WebPage",
      "name" => page_title,
      "description" => page_description,
      "url" => request.original_url
    }
  end
end