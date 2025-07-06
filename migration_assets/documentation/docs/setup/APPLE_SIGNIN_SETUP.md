# Apple Sign-In Setup Guide

## Prerequisites
- Apple Developer Account
- Xcode project with proper bundle identifier
- Firebase project configured

## Step 1: Enable Apple Sign-In Capability in Xcode

1. **Open your Xcode project**
2. **Select your target** (SAKungFuJournal)
3. **Go to "Signing & Capabilities" tab**
4. **Click the "+" button** to add a capability
5. **Search for "Sign In with Apple"**
6. **Add the capability**

## Step 2: Configure Apple Developer Console

1. **Go to [Apple Developer Console](https://developer.apple.com/account/)**
2. **Navigate to Certificates, Identifiers & Profiles**
3. **Select "Identifiers"**
4. **Find your app's identifier** (com.pjsengineering.samanual)
5. **Click on it to edit**
6. **Scroll down to "Sign In with Apple"**
7. **Check the box to enable it**
8. **Click "Configure"**
9. **Select "Primary App ID"**
10. **Save the changes**

## Step 3: Configure Firebase

1. **Go to [Firebase Console](https://console.firebase.google.com/)**
2. **Select your project** (shaolin-arts-manual)
3. **Go to Authentication > Sign-in method**
4. **Enable Apple as a sign-in provider**
5. **Add your bundle identifier**: `com.pjsengineering.samanual`
6. **Download the updated GoogleService-Info.plist**

## Step 4: Update Info.plist (Already Done)

The Info.plist has been updated with:
- Bundle identifier
- URL schemes for both Google and Apple Sign-In

## Step 5: Test the Implementation

1. **Build and run your app**
2. **Try signing in with Apple**
3. **Check Firebase Console to see if the user is created**

## Troubleshooting

### Common Issues:

1. **"MCPasscodeManager passcode set check is not supported"**
   - This is a simulator warning, not an error
   - Test on a real device for full functionality

2. **"Authorization failed: Error Domain=AKAuthenticationError Code=-7026"**
   - Apple Sign-In capability not enabled in Xcode
   - Bundle identifier mismatch
   - Apple Developer Console not configured

3. **"ASAuthorizationController credential request failed"**
   - Check that Sign In with Apple is enabled in Apple Developer Console
   - Verify bundle identifier matches everywhere

### Debug Steps:

1. **Check Xcode Capabilities**:
   - Ensure "Sign In with Apple" is listed in Signing & Capabilities
   - Verify no red error indicators

2. **Check Bundle Identifier**:
   - Must match in Xcode project settings
   - Must match in Apple Developer Console
   - Must match in Firebase Console

3. **Check Apple Developer Console**:
   - Sign In with Apple must be enabled for your app identifier
   - Configuration must be saved

4. **Test on Real Device**:
   - Apple Sign-In works best on physical devices
   - Simulator has limitations with Apple Sign-In

## Security Notes

- Apple Sign-In requires a real device for full testing
- The bundle identifier must be consistent across all platforms
- Apple Sign-In tokens are secure and don't require additional security measures

## Additional Resources

- [Apple Sign-In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Firebase Apple Sign-In Guide](https://firebase.google.com/docs/auth/ios/apple)
- [Apple Developer Console](https://developer.apple.com/account/)

## Current Status

✅ Info.plist configured
✅ FirebaseAuthService implemented
✅ AuthViewModel updated
✅ AuthView updated

⏳ Need to enable capability in Xcode
⏳ Need to configure Apple Developer Console 