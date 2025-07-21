# Universal Links Setup Guide for Safe Whisper

This guide explains how to set up Universal Links for the Safe Whisper app, allowing users to open Safe Whisper URLs directly in the iOS app instead of Safari.

## Overview

Universal Links allow iOS apps to handle web URLs directly. When a user taps a Safe Whisper link, it will open in the app instead of the browser (if the app is installed).

## Backend Implementation ✅

The backend now serves the Apple App Site Association file required for Universal Links:

### Endpoints Added

1. **`/.well-known/apple-app-site-association`** (Primary endpoint)
2. **`/apple-app-site-association`** (Alternative endpoint for testing)

### JSON Structure

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "RJ3GB6YDXL.pt.sousavf.Safe-Whisper",
        "paths": [
          "NOT /support/contact",
          "NOT /privacy/policy",
          "NOT /about/me",
          "/*"
        ]
      }
    ]
  }
}
```

### Path Configuration

- ✅ **`/*`** - Handle all URLs by default
- ❌ **`NOT /support/contact`** - Don't handle contact page
- ❌ **`NOT /privacy/policy`** - Don't handle privacy policy
- ❌ **`NOT /about/me`** - Don't handle about page

This means the app will handle message URLs but let web pages like contact, privacy policy, and about page open in Safari.

## iOS App Configuration Required

You'll need to configure the iOS app to handle Universal Links:

### 1. Add Associated Domains Entitlement

In `SecureMessagingApp.entitlements`, add:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:yourdomain.com</string>
    <string>applinks:www.yourdomain.com</string>
</array>
```

Replace `yourdomain.com` with your actual domain.

### 2. Handle Universal Links in App

In your `SceneDelegate.swift` or `AppDelegate.swift`, add:

```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    // Handle universal link
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
        // Handle the URL - extract message ID and key
        handleUniversalLink(url: url)
        return true
    }
    return false
}

private func handleUniversalLink(url: URL) {
    // Parse the URL and extract message information
    // Example: https://yourdomain.com/messageId#key
    let pathComponents = url.pathComponents
    if pathComponents.count >= 2 {
        let messageId = pathComponents[1]
        let key = url.fragment
        
        // Navigate to the receive view or handle the message
        // You can post a notification to update the UI
        NotificationCenter.default.post(
            name: NSNotification.Name("HandleSecureMessageURL"),
            object: nil,
            userInfo: ["url": url.absoluteString]
        )
    }
}
```

### 3. Update URL Scheme Handling

Make sure your existing `LinkManager.swift` can parse both custom scheme and HTTPS URLs:

```swift
class LinkManager {
    func parseShareableLink(_ urlString: String) -> ParsedLink? {
        // Handle both custom scheme and HTTPS URLs
        if urlString.starts(with: "https://") {
            // Parse HTTPS universal link
            guard let url = URL(string: urlString) else { return nil }
            // Extract message ID from path and key from fragment
            // Implementation depends on your URL structure
        } else {
            // Handle existing custom scheme
            // Your existing implementation
        }
    }
}
```

## Domain Setup Requirements

### 1. Deploy Backend

Deploy your backend with the Universal Links endpoint to your production domain:

```bash
# Deploy to your server
docker run -d \
  --name safe-whisper-backend \
  -p 8080:8080 \
  -e SPRING_DATASOURCE_URL="your_db_url" \
  -e DB_USERNAME="your_db_user" \
  -e DB_PASSWORD="your_db_password" \
  sousavfl/safe-whisper-backend:latest
```

### 2. Configure Web Server

If using nginx or Apache, ensure the `.well-known` directory is accessible:

#### Nginx Configuration

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    
    location /.well-known/apple-app-site-association {
        proxy_pass http://localhost:8080/.well-known/apple-app-site-association;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        add_header Content-Type application/json;
    }
    
    # Other proxy configurations...
}
```

#### Apache Configuration

```apache
<Location /.well-known/apple-app-site-association>
    ProxyPass http://localhost:8080/.well-known/apple-app-site-association
    ProxyPassReverse http://localhost:8080/.well-known/apple-app-site-association
    Header set Content-Type "application/json"
</Location>
```

### 3. Verify Endpoint

Test that your endpoint is accessible:

```bash
curl -H "Accept: application/json" https://yourdomain.com/.well-known/apple-app-site-association
```

Should return:
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "RJ3GB6YDXL.pt.sousavf.Safe-Whisper",
        "paths": ["NOT /support/contact", "NOT /privacy/policy", "NOT /about/me", "/*"]
      }
    ]
  }
}
```

## Testing Universal Links

### 1. Apple Universal Links Validator

Use Apple's validator tool:
- https://search.developer.apple.com/appsearch-validation-tool/

Enter your domain and verify the Apple App Site Association file.

### 2. Device Testing

1. **Install the app** on your iOS device
2. **Send yourself a message link** via Messages, Mail, or Notes
3. **Long press the link** - you should see "Open in Safe Whisper" option
4. **Tap the link** - it should open directly in the app

### 3. Safari Testing

1. Open Safari on iOS
2. Navigate to `https://yourdomain.com/your-message-url`
3. You should see a banner at the top offering to open in Safe Whisper

## Troubleshooting

### Common Issues

1. **Universal Links not working:**
   - Ensure the app is installed from App Store (not Xcode)
   - Verify the Apple App Site Association file is accessible via HTTPS
   - Check that the Team ID in appID matches your Apple Developer Team ID

2. **File not found (404):**
   - Verify the backend endpoint is working: `curl https://yourdomain.com/.well-known/apple-app-site-association`
   - Check web server configuration

3. **Wrong Content-Type:**
   - Ensure the endpoint returns `Content-Type: application/json`
   - No file extension should be used in the URL

4. **App ID mismatch:**
   - Verify your Team ID: `RJ3GB6YDXL`
   - Verify your Bundle ID: `pt.sousavf.Safe-Whisper`
   - Format should be: `TEAMID.BUNDLEID`

### Debug Commands

```bash
# Test the endpoint
curl -v https://yourdomain.com/.well-known/apple-app-site-association

# Check DNS resolution
nslookup yourdomain.com

# Test SSL certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
```

## URL Structure Recommendations

For best Universal Links experience, consider this URL structure:

```
https://yourdomain.com/{messageId}#{key}
```

Example:
```
https://safewhisper.com/550e8400-e29b-41d4-a716-446655440000#dGVzdEtleUZvclVuaXZlcnNhbExpbmtz
```

This allows:
- Clean URLs that work well with Universal Links
- Easy parsing in the iOS app
- Security (key in fragment, not sent to server)

## Security Considerations

1. **HTTPS Required:** Universal Links only work over HTTPS
2. **Key in Fragment:** Keep encryption keys in URL fragments (`#key`) - they're not sent to servers
3. **Path Exclusions:** Exclude non-app pages from Universal Links handling
4. **Domain Verification:** Apple verifies domain ownership through the association file

---

## Next Steps

1. ✅ **Backend implemented** - Universal Links endpoint is ready
2. 🔄 **Update iOS app** - Add associated domains and URL handling
3. 🔄 **Deploy to production** - Upload backend to your domain
4. 🔄 **Configure web server** - Ensure proper routing and headers
5. 🔄 **Test thoroughly** - Use Apple's validator and device testing

Your Safe Whisper backend now supports Universal Links! 🎉