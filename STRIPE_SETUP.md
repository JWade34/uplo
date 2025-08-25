# Stripe Live Payments Setup Guide

This document covers setting up Stripe live payments for production use with proper security measures.

## 🔧 Pre-Deployment Setup

### 1. Stripe Dashboard Configuration

#### Create Products & Price IDs
1. Log into [Stripe Dashboard](https://dashboard.stripe.com)
2. Switch to **Live Mode** (toggle in top-left)
3. Go to **Products** → **Create Product**

**Pro Monthly Plan:**
- Product Name: `Uplo Pro Monthly`
- Price: `$39.00 USD`
- Billing: `Monthly`
- Copy the **Price ID** (starts with `price_`)

**Pro Annual Plan:**
- Product Name: `Uplo Pro Annual`  
- Price: `$390.00 USD`
- Billing: `Yearly`
- Copy the **Price ID** (starts with `price_`)

#### Get API Keys
1. Go to **Developers** → **API Keys**
2. Copy **Publishable key** (starts with `pk_live_`)
3. Reveal and copy **Secret key** (starts with `sk_live_`)

#### Setup Webhook Endpoint
1. Go to **Developers** → **Webhooks**
2. Click **Add endpoint**
3. URL: `https://your-domain.com/webhooks/stripe`
4. Events to send:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`  
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
5. Copy the **Signing secret** (starts with `whsec_`)

#### Enable Customer Portal
1. Go to **Settings** → **Billing** → **Customer Portal**
2. Enable customer portal
3. Configure allowed actions:
   - Update payment method ✓
   - Cancel subscription ✓
   - View invoice history ✓

### 2. Environment Variables

Update your production environment with these variables:

```env
# Stripe Live Keys
STRIPE_PUBLISHABLE_KEY=pk_live_your_publishable_key_here
STRIPE_SECRET_KEY=sk_live_your_secret_key_here  
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here

# Stripe Price IDs (from products created above)
STRIPE_PRO_MONTHLY_PRICE_ID=price_your_monthly_price_id
STRIPE_PRO_YEARLY_PRICE_ID=price_your_yearly_price_id
```

**⚠️ Security Note:** Never commit live keys to version control!

### 3. Testing the Integration

Before going live, test with Stripe's test keys:

```bash
# Switch to test keys in .env
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
```

Use Stripe's [test card numbers](https://stripe.com/docs/testing):
- Success: `4242424242424242`
- Decline: `4000000000000002`
- 3D Secure: `4000000000003220`

## 🚀 Deployment Checklist

- [ ] Live Stripe products created with correct pricing
- [ ] Webhook endpoint configured and verified
- [ ] Environment variables set in production
- [ ] Customer portal enabled in Stripe dashboard
- [ ] SSL certificate active on domain
- [ ] Email notifications configured (see EMAIL_SETUP.md)
- [ ] Test successful subscription flow
- [ ] Test webhook events (use Stripe CLI: `stripe listen`)
- [ ] Test cancellation and reactivation flows
- [ ] Monitor error logs during first few transactions

## 🔒 Security Best Practices

### Webhook Verification
Our webhook handler verifies Stripe signatures:

```ruby
# In WebhooksController
event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
```

### PCI Compliance
- All card data handled by Stripe (PCI-compliant)
- No sensitive card data stored in our database
- Using Stripe Elements for secure card input

### Error Handling
- All Stripe API calls wrapped in try/catch
- Sensitive data excluded from error logs
- Graceful fallbacks for API failures

### Rate Limiting
Consider adding rate limiting to checkout endpoints:

```ruby
# Add to ApplicationController or CheckoutController
before_action :rate_limit_checkout, only: [:create]

private

def rate_limit_checkout
  # Implement rate limiting logic
end
```

## 📊 Monitoring & Analytics

### Key Metrics to Track
- Conversion rate (free → paid)
- Monthly recurring revenue (MRR)
- Customer lifetime value (CLV)
- Churn rate
- Failed payment rate

### Stripe Dashboard Insights
- Go to **Analytics** in Stripe dashboard
- Set up email alerts for failed payments
- Monitor subscription metrics

### Application Logging
Important events to log:
- Successful subscriptions
- Payment failures  
- Cancellations
- Webhook processing errors

## 🆘 Common Issues & Solutions

### Webhook Not Receiving Events
1. Check webhook URL is accessible
2. Verify webhook signing secret
3. Check firewall/security settings
4. Use Stripe CLI to test: `stripe listen --forward-to localhost:3000/webhooks/stripe`

### Payment Failures
1. Check card details are valid
2. Verify sufficient funds
3. Check for 3D Secure requirements
4. Review Stripe logs for decline reasons

### Subscription Status Issues
1. Ensure webhook events are processed correctly
2. Check database subscription records match Stripe
3. Verify status updates in webhook handlers

### Customer Portal Not Loading
1. Confirm customer portal is enabled in Stripe
2. Check customer ID is valid
3. Verify return URL is correct

## 🔄 Maintenance

### Regular Tasks
- [ ] Monitor failed payments weekly
- [ ] Review subscription metrics monthly
- [ ] Update expired cards proactively
- [ ] Audit webhook events for processing errors

### Updates & Changes
- Test all changes in Stripe test mode first
- Coordinate price changes with marketing
- Update webhook handlers when adding new events
- Monitor error rates after deployments

## 📞 Support Resources

- [Stripe Documentation](https://stripe.com/docs)
- [Stripe Support](https://support.stripe.com/)
- [Webhook Testing](https://stripe.com/docs/webhooks/test)
- [API Reference](https://stripe.com/docs/api)

---

**Need Help?** Contact the development team or create an issue in the repository.