class TermsController < ApplicationController
  skip_before_action :require_authentication
  
  def terms_of_service
    @page_title = "Terms of Service"
  end
  
  def privacy_policy
    @page_title = "Privacy Policy"
  end
  
  def fair_use_policy
    @page_title = "Fair Use Policy"
  end
end