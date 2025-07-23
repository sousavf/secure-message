# Premium Image Sharing Setup Guide

This guide outlines the setup process for implementing premium image sharing functionality with App Store subscriptions in Safe Whisper.

## Implementation Summary

### Backend Changes
- ✅ Created `User` entity to track subscription status and device IDs
- ✅ Implemented `SubscriptionService` for Apple receipt verification
- ✅ Added subscription management REST endpoints
- ✅ Enhanced `Message` entity to support 10MB+ content
- ✅ Added size validation based on subscription tier

### iOS App Changes
- ✅ Integrated StoreKit 2 for subscription management
- ✅ Added image picker with PhotosUI
- ✅ Implemented image compression and size validation
- ✅ Created subscription paywall UI
- ✅ Enhanced message composition with image support
- ✅ Updated message viewing to display images

## App Store Connect Setup Required

### 1. Configure In-App Purchases
1. In App Store Connect, go to your app → Features → In-App Purchases
2. Create two subscription products:
   - **Monthly Premium**: `pt.sousavf.Safe-Whisper.premium.monthly`
   - **Yearly Premium**: `pt.sousavf.Safe-Whisper.premium.yearly`

3. Configure subscription details:
   - **Subscription Group**: Create "Premium Features"
   - **Pricing**: Set your preferred pricing tiers
   - **Description**: "Premium features including 10MB image sharing"

### 2. App Store Review Information
- Clearly describe premium features in app description
- Include subscription terms and pricing
- Provide restore functionality
- Add privacy policy updates for subscription data

### 3. Sandbox Testing
1. Create sandbox test accounts in App Store Connect
2. Test subscription purchase flow
3. Test subscription restoration
4. Test subscription expiration handling

## Environment Configuration

### Backend Configuration
Add these environment variables:

```bash
# Apple App Store Configuration
APP_SHARED_SECRET=your-app-shared-secret-from-app-store-connect
SUBSCRIPTION_SANDBOX=true  # Set to false in production

# Database configuration will auto-create new tables
SPRING_JPA_HIBERNATE_DDL_AUTO=update  # For production
```

### iOS Configuration
Update product identifiers in `SubscriptionManager.swift` to match your App Store Connect configuration:

```swift
private let subscriptionProductIDs = [
    "pt.sousavf.Safe-Whisper.premium.monthly",
    "pt.sousavf.Safe-Whisper.premium.yearly"
]
```

## Features Implemented

### Premium Features (10MB Image Sharing)
- ✅ Image picker integration with photo library access
- ✅ Automatic image compression for optimal upload size
- ✅ Client-side encryption of image data (base64 encoded)
- ✅ Server-side size validation based on subscription status
- ✅ Enhanced message viewing with image display
- ✅ Save image functionality for received images

### Subscription Management
- ✅ StoreKit 2 integration with modern async/await APIs
- ✅ Automatic subscription status synchronization
- ✅ Backend receipt verification with Apple's servers
- ✅ Subscription status UI in Settings
- ✅ Paywall integration for premium features

### Free Tier Limitations
- ✅ 100KB message size limit for free users
- ✅ Text-only messaging for free users
- ✅ Upgrade prompts when attempting to use premium features

## Security Considerations

### Privacy Protection
- Device IDs are used instead of personal information
- Subscription receipts are securely validated with Apple
- No sensitive user data is stored on the backend
- Images are encrypted client-side before transmission

### Data Handling
- Images are base64 encoded and encrypted
- Subscription status is cached locally for performance
- Receipt validation happens server-side for security
- User data is automatically cleaned up after expiration

## Testing Checklist

### Subscription Flow Testing
- [ ] Purchase subscription with sandbox account
- [ ] Verify backend receives and validates subscription
- [ ] Test subscription status updates in app
- [ ] Test subscription restoration
- [ ] Test subscription expiration handling

### Image Sharing Testing
- [ ] Test image selection from photo library
- [ ] Verify image compression for different sizes
- [ ] Test 10MB image upload for premium users
- [ ] Verify size rejection for free users
- [ ] Test image viewing and saving functionality

### Error Handling Testing
- [ ] Test network failures during subscription verification
- [ ] Test invalid receipt handling
- [ ] Test oversized image rejection
- [ ] Test expired subscription behavior

## Deployment Notes

### Database Migration
The backend will automatically create new tables:
- `users` - User subscription tracking
- Enhanced `messages` table with larger content support

### Production Configuration
1. Set `SUBSCRIPTION_SANDBOX=false` in production
2. Configure proper `APP_SHARED_SECRET` from App Store Connect
3. Update CORS origins for production domain
4. Monitor subscription verification logs

## Next Steps

1. **App Store Review Preparation**:
   - Update app description to mention premium features
   - Prepare screenshots showing image sharing
   - Create subscription marketing materials

2. **Analytics Implementation**:
   - Track subscription conversion rates
   - Monitor image sharing usage
   - Implement subscription churn analytics

3. **Enhanced Features** (Future):
   - Video sharing for premium users
   - File attachment support
   - Advanced image editing features

## Support and Troubleshooting

### Common Issues
- **Subscription not recognized**: Check sandbox vs production environment
- **Image upload fails**: Verify device subscription status sync
- **Receipt validation fails**: Check APP_SHARED_SECRET configuration

### Logs to Monitor
- Subscription verification attempts
- Message size validation failures
- Image processing errors
- Receipt validation responses

This implementation provides a solid foundation for premium image sharing functionality while maintaining the app's core security and privacy principles.