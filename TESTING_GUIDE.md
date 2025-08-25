# Payment System Testing Guide

## 🧪 Test Environment Setup

✅ **Environment**: Currently configured with Stripe test keys
✅ **Test Price IDs**: Active for monthly/yearly plans
✅ **Webhook**: Configured for development mode

## 🧾 Test Cards for Payment Testing

Use these Stripe test card numbers:

### Successful Payments
- **Visa**: `4242424242424242`
- **Visa (debit)**: `4000056655665556`
- **Mastercard**: `5555555555554444`
- **American Express**: `378282246310005`

### Payment Failures
- **Generic decline**: `4000000000000002`
- **Insufficient funds**: `4000000000009995`
- **Lost card**: `4000000000009987`
- **Stolen card**: `4000000000009979`

### Special Cases
- **3D Secure authentication**: `4000000000003220`
- **Requires authentication**: `4000002500003155`

**For all test cards:**
- Use any future expiry date (e.g., `12/34`)
- Use any 3-digit CVC (e.g., `123`)
- Use any billing postal code

## 📋 Testing Checklist

### Phase 1: Basic Payment Flow ✅

**Start your server:** `bin/dev`

1. **Navigate to pricing page**: http://localhost:3000/pricing
   - [ ] Page loads without errors
   - [ ] Both monthly ($39) and annual ($390) plans visible
   - [ ] Social proof and testimonials display
   - [ ] Feature comparison table shows correctly

2. **Test Monthly Plan Signup**:
   - [ ] Click "Start Free Trial" on monthly plan
   - [ ] Redirected to Stripe Checkout
   - [ ] Use test card: `4242424242424242`
   - [ ] Complete payment successfully
   - [ ] Redirected to success page with celebration
   - [ ] Account shows Pro status

3. **Test Annual Plan Signup**:
   - [ ] Create new test account or reset subscription
   - [ ] Click "Start Free Trial" on annual plan
   - [ ] Complete payment with test card
   - [ ] Verify savings display ($78/year)

4. **Test Payment Failures**:
   - [ ] Try card `4000000000000002` (generic decline)
   - [ ] Verify error handling works gracefully
   - [ ] User is redirected appropriately

### Phase 2: User Experience Flow

5. **Test Upgrade Prompts**:
   - [ ] Create free account
   - [ ] Upload 4-5 photos to near the limit
   - [ ] Verify "almost at limit" warning appears
   - [ ] Upload final photo to hit limit
   - [ ] Verify "limit reached" strong CTA appears
   - [ ] Click upgrade prompt and complete payment

6. **Test Onboarding Integration**:
   - [ ] Complete new user onboarding
   - [ ] Verify upgrade prompt appears on completion page
   - [ ] Test upgrade flow from onboarding

### Phase 3: Subscription Management

7. **Test Billing Dashboard**: http://localhost:3000/billing
   - [ ] View current plan details
   - [ ] Check usage statistics display
   - [ ] Verify subscription status shows correctly

8. **Test Subscription Actions**:
   - [ ] Click "Update Payment Method" 
   - [ ] Verify Stripe Customer Portal loads
   - [ ] Test cancellation flow
   - [ ] Verify "canceled at period end" status
   - [ ] Test reactivation

### Phase 4: Navigation & Edge Cases

9. **Test Navigation**:
   - [ ] Logged-out user sees "Sign In" and "View Plans"
   - [ ] Logged-in free user sees upgrade badges
   - [ ] Pro user sees billing management options

10. **Test Cancel Flow**:
    - [ ] Start checkout and cancel
    - [ ] Verify cancel page with win-back offers
    - [ ] Test "21-day extended trial" messaging

## 🎯 Webhook Testing

To test webhooks locally, you'll need Stripe CLI:

```bash
# Install Stripe CLI (if not installed)
brew install stripe/stripe-cli/stripe

# Login to your Stripe account
stripe login

# Forward webhooks to local server
stripe listen --forward-to localhost:3000/webhooks/stripe
```

**Test webhook events:**
1. Complete a test payment
2. Check your Rails logs for webhook processing
3. Verify subscription created in database:
   ```bash
   bin/rails console
   User.last.subscriptions.last
   ```

## 🐛 Common Issues & Solutions

### Checkout Not Loading
- Check Stripe keys are test keys (start with `pk_test_` and `sk_test_`)
- Verify price IDs exist in Stripe dashboard (test mode)
- Check browser console for JavaScript errors

### Webhook Failures
- Ensure webhook signature verification is working
- Check Rails logs: `tail -f log/development.log`
- Verify webhook endpoint is accessible

### Database Issues
- Run migrations: `bin/rails db:migrate`
- Check subscription records: `bin/rails console` → `Subscription.all`

## ✅ Success Criteria

**All tests passing means:**
- [ ] Payment flow works end-to-end
- [ ] Webhooks process correctly
- [ ] Subscription status updates in database
- [ ] User experience is smooth and intuitive
- [ ] Error handling is graceful
- [ ] All upgrade prompts work
- [ ] Billing management is functional

## 🚀 Ready for Production

Once all tests pass, you can:
1. Switch to live Stripe keys
2. Create live products in Stripe
3. Configure production webhooks
4. Deploy to production

---

**Testing Status**: 
- [ ] Phase 1: Basic Payment Flow
- [ ] Phase 2: User Experience Flow  
- [ ] Phase 3: Subscription Management
- [ ] Phase 4: Navigation & Edge Cases
- [ ] Webhook Testing Complete

**Next Steps**: After testing complete, proceed to production setup.