# Google Sign-In Setup Guide

## Prerequisites
- Firebase project configured
- iOS app bundle identifier
- Google Cloud Console access

## Step 1: Add Google Sign-In SDK

### Option A: Using Swift Package Manager (Recommended)
1. In Xcode, go to File > Add Package Dependencies
2. Enter the URL: `https://github.com/google/GoogleSignIn-iOS.git`
3. Select the latest version and add to your target

### Option B: Using CocoaPods
Add to your Podfile:
```ruby
pod 'GoogleSignIn'
```

## Step 2: Configure Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Go to APIs & Services > Credentials
4. Create or configure OAuth 2.0 Client ID for iOS
5. Add your bundle identifier (e.g., `com.yourcompany.SAKungFuJournal`)
6. Download the `GoogleService-Info.plist` file if you haven't already

## Step 3: Configure Firebase

1. In Firebase Console, go to Authentication > Sign-in method
2. Enable Google as a sign-in provider
3. Add your iOS app's bundle identifier
4. Download the updated `GoogleService-Info.plist`

## Step 4: Update Info.plist

Add the following to your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_REVERSED_CLIENT_ID` with the value from your `GoogleService-Info.plist` file.

## Step 5: Update App Delegate

In your `SAKungFuJournalApp.swift`, add URL handling:

```swift
import GoogleSignIn

// In your AppDelegate class, add:
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return GIDSignIn.sharedInstance.handle(url)
}
```

## Step 6: Test the Implementation

1. Build and run your app
2. Try signing in with Google
3. Check Firebase Console to see if the user is created

## Troubleshooting

### Common Issues:
1. **"Google client ID not found"**: Make sure `GoogleService-Info.plist` is in your project
2. **URL scheme not working**: Verify the reversed client ID in Info.plist
3. **Sign-in fails**: Check that Google Sign-In is enabled in Firebase Console

### Debug Steps:
1. Check Xcode console for error messages
2. Verify bundle identifier matches in all places
3. Ensure `GoogleService-Info.plist` is up to date

## Security Notes

- Never commit `GoogleService-Info.plist` to public repositories
- Use different OAuth client IDs for development and production
- Regularly rotate your OAuth client secrets

## Additional Resources

- [Google Sign-In iOS Documentation](https://developers.google.com/identity/sign-in/ios)
- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth)
- [Google Cloud Console](https://console.cloud.google.com/) 