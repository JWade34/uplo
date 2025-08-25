class BillingController < ApplicationController
  before_action :require_authentication
  
  def index
    @user = Current.user
    @active_subscription = @user.active_subscription
    @subscriptions = @user.subscriptions.order(created_at: :desc).limit(5)
    
    # Calculate usage statistics
    @user.reset_monthly_usage_if_needed
    @usage_stats = {
      photos_used: @user.current_month_photos,
      photos_limit: @user.effective_monthly_photo_limit,
      photos_remaining: @user.photos_remaining_this_month,
      photos_percentage: @user.usage_percentage(:photos),
      captions_used: @user.current_month_captions,
      captions_limit: @user.effective_monthly_caption_limit,
      captions_remaining: @user.captions_remaining_this_month,
      captions_percentage: @user.usage_percentage(:captions)
    }
    
    # Get upcoming invoice if subscribed
    if @active_subscription&.stripe_subscription_id
      begin
        @upcoming_invoice = Stripe::Invoice.upcoming(
          customer: @active_subscription.stripe_customer_id
        )
      rescue Stripe::InvalidRequestError
        # No upcoming invoice (might be in trial or canceled)
        @upcoming_invoice = nil
      end
    end
  end
  
  def update_payment_method
    # Redirect to Stripe Customer Portal for payment method updates
    begin
      subscription = Current.user.active_subscription
      
      if subscription&.stripe_customer_id
        portal_session = Stripe::BillingPortal::Session.create({
          customer: subscription.stripe_customer_id,
          return_url: billing_url
        })
        
        redirect_to portal_session.url, allow_other_host: true
      else
        redirect_to billing_path, alert: 'No active subscription found.'
      end
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe portal error: #{e.message}"
      redirect_to billing_path, alert: 'Unable to access billing portal. Please try again.'
    end
  end
  
  def cancel_subscription
    subscription = Current.user.active_subscription
    
    if subscription&.stripe_subscription_id
      begin
        # Cancel at period end (user keeps access until end of billing period)
        stripe_subscription = Stripe::Subscription.update(
          subscription.stripe_subscription_id,
          { cancel_at_period_end: true }
        )
        
        subscription.update!(
          status: 'canceled',
          cancel_at_period_end: true
        )
        
        redirect_to billing_path, notice: "Your subscription will be canceled at the end of your current billing period (#{subscription.current_period_end.strftime('%B %d, %Y')}). You'll continue to have Pro access until then."
      rescue Stripe::StripeError => e
        Rails.logger.error "Subscription cancellation error: #{e.message}"
        redirect_to billing_path, alert: 'Unable to cancel subscription. Please contact support.'
      end
    else
      redirect_to billing_path, alert: 'No active subscription to cancel.'
    end
  end
  
  def reactivate_subscription
    subscription = Current.user.active_subscription
    
    if subscription&.stripe_subscription_id && subscription.cancel_at_period_end
      begin
        # Remove cancellation
        stripe_subscription = Stripe::Subscription.update(
          subscription.stripe_subscription_id,
          { cancel_at_period_end: false }
        )
        
        subscription.update!(
          status: 'active',
          cancel_at_period_end: false
        )
        
        redirect_to billing_path, notice: 'Your subscription has been reactivated successfully!'
      rescue Stripe::StripeError => e
        Rails.logger.error "Subscription reactivation error: #{e.message}"
        redirect_to billing_path, alert: 'Unable to reactivate subscription. Please contact support.'
      end
    else
      redirect_to billing_path, alert: 'No canceled subscription to reactivate.'
    end
  end
  
  def download_invoice
    invoice_id = params[:invoice_id]
    
    begin
      invoice = Stripe::Invoice.retrieve(invoice_id)
      
      # Verify this invoice belongs to the current user
      subscription = Current.user.active_subscription
      if subscription&.stripe_customer_id == invoice.customer
        redirect_to invoice.invoice_pdf, allow_other_host: true
      else
        redirect_to billing_path, alert: 'Invoice not found.'
      end
    rescue Stripe::StripeError => e
      Rails.logger.error "Invoice download error: #{e.message}"
      redirect_to billing_path, alert: 'Unable to download invoice. Please try again.'
    end
  end
  
  private
  
  def subscription_status_class(status)
    case status
    when 'active', 'trialing'
      'bg-green-100 text-green-800'
    when 'past_due', 'incomplete'
      'bg-yellow-100 text-yellow-800'
    when 'canceled', 'unpaid'
      'bg-red-100 text-red-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
  helper_method :subscription_status_class
end