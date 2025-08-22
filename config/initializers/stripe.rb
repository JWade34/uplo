Stripe.api_key = ENV['STRIPE_SECRET_KEY']

Rails.application.config.stripe = {
  publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
  secret_key: ENV['STRIPE_SECRET_KEY'],
  signing_secret: ENV['STRIPE_WEBHOOK_SECRET']
}