class CheckoutController < ApplicationController
  before_action :require_authentication
  
  # Pricing configuration with live price IDs
  PLANS = {
    'starter_monthly' => {
      price_id: ENV['STRIPE_STARTER_MONTHLY_PRICE_ID'],
      amount: 19.00,
      interval: 'month',
      plan_name: 'Starter',
      display_name: 'Starter Monthly',
      savings: nil
    },
    'pro_monthly' => {
      price_id: ENV['STRIPE_PRO_MONTHLY_PRICE_ID'],
      amount: 39.00,
      interval: 'month',
      plan_name: 'Pro Monthly',
      display_name: 'Pro Monthly',
      savings: nil
    },
    'pro_yearly' => {
      price_id: ENV['STRIPE_PRO_YEARLY_PRICE_ID'],
      amount: 390.00,
      interval: 'year', 
      plan_name: 'Pro Annual',
      display_name: 'Pro Annual',
      savings: 78.00 # Save $78 compared to monthly
    }
  }.freeze

  def create
    plan_id = params[:plan_id] || 'pro_monthly'
    plan = PLANS[plan_id]
    
    unless plan
      redirect_to dashboard_path, alert: 'Invalid plan selected'
      return
    end
    
    begin
      # Create or get Stripe customer
      customer = get_or_create_stripe_customer
      
      # Create checkout session
      session = Stripe::Checkout::Session.create({
        customer: customer.id,
        payment_method_types: ['card'],
        line_items: [{
          price: plan[:price_id],
          quantity: 1,
        }],
        mode: 'subscription',
        subscription_data: {
          trial_period_days: 14,
          metadata: {
            user_id: Current.user.id.to_s,
            plan_name: plan[:plan_name]
          }
        },
        success_url: "#{request.base_url}/checkout/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{request.base_url}/checkout/cancel",
        metadata: {
          user_id: Current.user.id.to_s,
          plan_id: plan_id
        }
      })
      
      redirect_to session.url, allow_other_host: true
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe checkout error: #{e.message}"
      redirect_to dashboard_path, alert: 'Unable to process payment at this time. Please try again.'
    end
  end

  def success
    session_id = params[:session_id]
    
    if session_id
      begin
        session = Stripe::Checkout::Session.retrieve(session_id)
        
        if session.payment_status == 'paid' || session.mode == 'subscription'
          @success_message = 'Payment successful! Your Pro features are now active.'
          @subscription = Current.user.active_subscription
        else
          @error_message = 'Payment was not completed. Please contact support if you believe this is an error.'
        end
      rescue Stripe::StripeError => e
        Rails.logger.error "Error retrieving checkout session: #{e.message}"
        @error_message = 'Unable to verify payment status. Please contact support.'
      end
    else
      @error_message = 'No payment session found.'
    end
  end

  def cancel
    @cancel_message = 'Payment was cancelled. You can try again anytime.'
  end
  
  private
  
  def get_or_create_stripe_customer
    # Check if user already has a Stripe customer ID
    existing_subscription = Current.user.subscriptions.order(created_at: :desc).first
    
    if existing_subscription&.stripe_customer_id
      Stripe::Customer.retrieve(existing_subscription.stripe_customer_id)
    else
      # Create new Stripe customer
      Stripe::Customer.create({
        email: Current.user.email_address,
        metadata: {
          user_id: Current.user.id
        }
      })
    end
  end
end
