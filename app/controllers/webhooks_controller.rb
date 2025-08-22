class WebhooksController < ApplicationController
  protect_from_forgery except: :stripe
  skip_before_action :require_authentication
  
  def stripe
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = Rails.application.config.stripe[:signing_secret]
    
    begin
      # Skip signature verification in development if webhook secret is placeholder
      if Rails.env.development? && endpoint_secret == 'whsec_test_placeholder'
        event = JSON.parse(payload, symbolize_names: true)
        Rails.logger.info "Development mode: Skipping webhook signature verification"
      else
        event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON: #{e.message}"
      render json: { error: 'Invalid JSON' }, status: 400
      return
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "Invalid signature: #{e.message}"
      render json: { error: 'Invalid signature' }, status: 400
      return
    end

    # Handle the event
    event_type = event['type'] || event[:type]
    event_data = event['data'] || event[:data]
    event_object = event_data['object'] || event_data[:object]
    
    Rails.logger.info "Processing webhook event: #{event_type}"
    
    case event_type
    when 'checkout.session.completed'
      handle_checkout_session_completed(event_object)
    when 'customer.subscription.created'
      handle_subscription_created(event_object)
    when 'customer.subscription.updated'
      handle_subscription_updated(event_object)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event_object)
    when 'invoice.payment_succeeded'
      handle_payment_succeeded(event_object)
    when 'invoice.payment_failed'
      handle_payment_failed(event_object)
    else
      Rails.logger.info "Unhandled event type: #{event_type}"
    end

    render json: { status: 'success' }
  end
  
  private
  
  def handle_checkout_session_completed(session)
    metadata = session['metadata'] || session[:metadata] || {}
    user_id = metadata['user_id'] || metadata[:user_id]
    return unless user_id
    
    user = User.find(user_id)
    subscription_id = session['subscription'] || session[:subscription]
    
    if subscription_id
      begin
        # Retrieve the subscription from Stripe to get full details
        stripe_subscription = Stripe::Subscription.retrieve(subscription_id)
        create_or_update_subscription(user, stripe_subscription)
      rescue Stripe::InvalidRequestError => e
        # Handle test subscriptions that don't exist in Stripe
        if Rails.env.development? && subscription_id.start_with?('sub_test_')
          Rails.logger.info "Test subscription detected: #{subscription_id}"
          create_test_subscription(user, subscription_id, session)
        else
          raise e
        end
      end
    end
  rescue => e
    Rails.logger.error "Error handling checkout session completed: #{e.message}"
  end
  
  def handle_subscription_created(stripe_subscription)
    user_id = stripe_subscription['metadata']['user_id']
    return unless user_id
    
    user = User.find(user_id)
    create_or_update_subscription(user, stripe_subscription)
  rescue => e
    Rails.logger.error "Error handling subscription created: #{e.message}"
  end
  
  def handle_subscription_updated(stripe_subscription)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription['id'])
    return unless subscription
    
    update_subscription_from_stripe(subscription, stripe_subscription)
  rescue => e
    Rails.logger.error "Error handling subscription updated: #{e.message}"
  end
  
  def handle_subscription_deleted(stripe_subscription)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription['id'])
    return unless subscription
    
    subscription.update!(
      status: 'canceled',
      current_period_end: Time.at(stripe_subscription['current_period_end'])
    )
  rescue => e
    Rails.logger.error "Error handling subscription deleted: #{e.message}"
  end
  
  def handle_payment_succeeded(invoice)
    subscription_id = invoice['subscription']
    return unless subscription_id
    
    subscription = Subscription.find_by(stripe_subscription_id: subscription_id)
    return unless subscription
    
    # Update subscription status to active if it was past_due
    if subscription.status == 'past_due'
      subscription.update!(status: 'active')
    end
  rescue => e
    Rails.logger.error "Error handling payment succeeded: #{e.message}"
  end
  
  def handle_payment_failed(invoice)
    subscription_id = invoice['subscription']
    return unless subscription_id
    
    subscription = Subscription.find_by(stripe_subscription_id: subscription_id)
    return unless subscription
    
    subscription.update!(status: 'past_due')
  rescue => e
    Rails.logger.error "Error handling payment failed: #{e.message}"
  end
  
  def create_or_update_subscription(user, stripe_subscription)
    price = stripe_subscription['items']['data'][0]['price']
    amount = price['unit_amount'] / 100.0 # Convert cents to dollars
    
    subscription_attrs = {
      stripe_subscription_id: stripe_subscription['id'],
      stripe_customer_id: stripe_subscription['customer'],
      status: stripe_subscription['status'],
      current_period_start: Time.at(stripe_subscription['current_period_start']),
      current_period_end: Time.at(stripe_subscription['current_period_end']),
      trial_end: stripe_subscription['trial_end'] ? Time.at(stripe_subscription['trial_end']) : nil,
      amount: amount,
      interval: price['recurring']['interval'],
      plan_name: stripe_subscription['metadata']['plan_name'] || 'Pro'
    }
    
    # Find existing subscription or create new one
    subscription = user.subscriptions.find_by(stripe_subscription_id: stripe_subscription['id'])
    
    if subscription
      subscription.update!(subscription_attrs)
    else
      user.subscriptions.create!(subscription_attrs)
    end
  end
  
  def update_subscription_from_stripe(subscription, stripe_subscription)
    price = stripe_subscription['items']['data'][0]['price']
    amount = price['unit_amount'] / 100.0
    
    subscription.update!(
      status: stripe_subscription['status'],
      current_period_start: Time.at(stripe_subscription['current_period_start']),
      current_period_end: Time.at(stripe_subscription['current_period_end']),
      trial_end: stripe_subscription['trial_end'] ? Time.at(stripe_subscription['trial_end']) : nil,
      amount: amount,
      interval: price['recurring']['interval']
    )
  end
  
  def create_test_subscription(user, subscription_id, session)
    metadata = session['metadata'] || session[:metadata] || {}
    plan_id = metadata['plan_id'] || metadata[:plan_id] || 'pro_monthly'
    
    # Determine plan details based on plan_id
    case plan_id
    when 'pro_yearly'
      amount = 390.0
      interval = 'year'
    when 'pro_monthly'
      amount = 39.0
      interval = 'month'
    else
      amount = 39.0
      interval = 'month'
    end
    
    subscription_attrs = {
      stripe_subscription_id: subscription_id,
      stripe_customer_id: "cus_test_customer_#{user.id}",
      status: 'trialing',
      current_period_start: Time.current,
      current_period_end: Time.current + (interval == 'year' ? 1.year : 1.month),
      trial_end: Time.current + 14.days,
      amount: amount,
      interval: interval,
      plan_name: 'Pro'
    }
    
    # Find existing subscription or create new one
    subscription = user.subscriptions.find_by(stripe_subscription_id: subscription_id)
    
    if subscription
      subscription.update!(subscription_attrs)
    else
      user.subscriptions.create!(subscription_attrs)
    end
    
    Rails.logger.info "Created test subscription for user #{user.id}: #{subscription_id}"
  end
end
