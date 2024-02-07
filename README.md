# Firebase Authentication Service [![Pub Version](https://img.shields.io/pub/v/stacked_firebase_auth)](https://pub.dev/packages/stacked_firebase_auth)

This package is meant to work with the [Stacked framework](https://pub.dev/packages/stacked) and provides a `FirebaseAuthenticationService` that provides the following logins:

- [Email/password](#integrate-emailpassword-authentication)
- [Google](#Google)
- [Apple](#Apple)
- [Facebook](#Facebook)
- [Anonymous](#Integrate-anonymous-authentication)

It wraps the functionality for those four auth providers. Examples to come soon. This package has initially been published to improve the [BoxtOut tutorial](https://youtube.com/playlist?list=PLdTodMosi-BzqMe7fU9Bin3z14_hqNHRA) for setting up Firebase Auth.

## Dependencies

This package is relying on the following great packages to support the social providers:
- [google_sign_in](https://pub.dev/packages/google_sign_in)
- [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple)
- [flutter_facebook_auth](https://pub.dev/packages/flutter_facebook_auth)

## How does it work? 

1. [Configure your Firebase project to enable authentication](#Configure-a-basic-Firebase-Authentication-project)
2. [Configure your Flutter project with Firebase](#Configure-a-basic-Firebase-Authentication-project)
3. [Install the package and register the service](#Install-the-package-and-register-the-service)
4. Integrate the desired social authentication provider(s)
    1. [Google](#Google)
    2. [Apple](#Apple)
    3. [Facebook](#Facebook)
5. [Integrate email/password authentication](#integrate-emailpassword-authentication)
6. [Integrate anonymous authentication](#Integrate-anonymous-authentication)
7. [Logout](#Logout)
8. [Troubleshooting](#Troubleshooting)


### Configure a basic Firebase Authentication project

1.  Go to the [Firebase Console](https://console.firebase.google.com) and create a new project
2. In the `Build` section, chose `Authentication`, then click on `Get started` to enable it. 
3. You are now able to chose which providers you want to enable. For each of them, we have a small guide here-under. 

You can find official doc and information on [https://firebase.google.com/docs/auth](https://firebase.google.com/docs/auth).

### Integrate and configure Firebase to your project

💡 More info about this process here: [https://firebase.google.com/docs/flutter/setup](https://firebase.google.com/docs/flutter/setup)

#### Step 1: Install the required command line tools (once)

1. If you haven't already, [install the Firebase CLI](https://firebase.google.com/docs/cli?authuser=0#setup_update_cli).
2. Log into Firebase using your Google account by running the following command: `firebase login`.
3. Install the FlutterFire CLI with the following dart command : `dart pub global activate flutterfire_cli`.

#### Step 2: Configure your apps to use Firebase (on each project)

1. Use the flutterfire CLI to enable Firebase and create the configuration files in your project: `flutterfire configure`. You will be asked to select the project you want to configure and the platforms you want to enable. 
2. In your `lib/main.dart`, you will now be able to add `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);` to initialise the default instance of Firebase. 

```
// Add those imports
import 'package:example/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Add this line
  Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  await setupLocator();
  setupDialogUi();
  setupBottomSheetUi();
  runApp(const MainApp());
}

```

### Install the package and register the service

1. If you support iOS, update the `ios\Podfile` to include `platform :ios, '12.0'`
2. If you support Android, update `android/app/build.gradle` to define `minSdkVersion` to `21`
```
defaultConfig {
    ...
    minSdkVersion 21
    targetSdkVersion 33
    ...
}
```

3. Run `flutter pub add stacked_firebase_auth` to add the package to your dependencies
4. In your `lib\app\app.dart` file, add `LazySingleton(classType: FirebaseAuthenticationService),`at the end of the `dependencies` list. 

```
@StackedApp(
  routes: [ ... ],
  dependencies: [
    // Other dependencies
    LazySingleton(classType: FirebaseAuthenticationService),
  ],
  bottomsheets: [ ... ],
  dialogs: [ ... ],
)
class App {}

```

4. Regenerate your app via the Stacked CLI: `stacked generate`
5. You can now fetch and use the `FirebaseAuthenticationService` from `locator<FirebaseAuthenticationService>()`. 

### Integrate the social authentication providers

Note that according to [https://developer.apple.com/sign-in-with-apple/get-started](https://developer.apple.com/sign-in-with-apple/get-started/), starting June 30, 2020, apps that use login services must also offer a "Sign in with Apple" option when submitting to the Apple App Store.

#### Google

This package is heavily relying on [google_sign_in](https://pub.dev/packages/google_sign_in). Please follow the configuration process described on their doc the the platforms you want to support. 

You will find how-to
1. Create an OAuth app on [Google Cloud Console](https://console.cloud.google.com)
2. Activate the Google Sign-in provider on [Firebase Console](https://console.firebase.google.com) and link to your OAuth app
3. Run `flutterfire configure` again to update config files
4. [iOS](https://pub.dev/packages/google_sign_in#ios-integration) Add required information to `ios/Runner/Info.plist`
5. [Android](https://pub.dev/packages/google_sign_in#android-integration) Add SHA1 or SHA256 to app configuration

Once done you can use the following method to trigger Google Sign-in flow: 

```
Future<FirebaseAuthenticationResult> signInWithGoogle({String? webLoginHint})
```

#### Apple

This package is heavily relying on [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple). Please follow the configuration process described on their doc the the platforms you want to support. 

You will find how-to
1. Register an App ID on [https://developer.apple.com/account/resources/identifiers/list/bundleId](https://developer.apple.com/account/resources/identifiers/list/bundleId)
2. Activate the Apple Sign-in provider on [Firebase Console](https://console.firebase.google.com) + configure the callback URL in the Service IDs. 
3. [iOS](https://pub.dev/packages/sign_in_with_apple#ios) Activate Sign in with Apple capability through XCode
4 [Android](https://pub.dev/packages/sign_in_with_apple#android) Ensure the authentication window will be run via a full external browser (otherwise authentication might fail with storage access error). 

To know if Apple Signin is available on the platform and if you need to display the button, you can use 
```
Future<bool> isAppleSignInAvailable()
```

Then, to trigger the flow, just use

```
  Future<FirebaseAuthenticationResult> signInWithApple({
    required String? appleRedirectUri,
    required String? appleClientId,
    bool askForFullName = true,
  })
```

#### Facebook

This package is heavily relying on [flutter_facebook_auth](https://pub.dev/packages/flutter_facebook_auth). Please follow the configuration process described on their doc the the platforms you want to support. 

You will find how-to
1. Create and configure the app on [Facebook](https://developers.facebook.com)
2. Activate the Facebook Sign-in provider on [Firebase Console](https://console.firebase.google.com) and link to your OAuth app
3. [iOS](https://facebook.meedu.app/docs/6.x.x/ios) Add required information to Podfile, `ios/Runner/Info.plist`, 
4. [Android](https://facebook.meedu.app/docs/6.x.x/android) Add required resources and configuration files (in `/android/app/src/main/res/values/strings.xml` and `/android/app/src/main/AndroidManifest.xml`)


Once done you can use the following method to trigger Facebook Sign-in flow: 

```
Future<FirebaseAuthenticationResult> signInWithFacebook({String? webLoginHint})
```

### Integrate email/password authentication

💡 More info about this authentication here: [https://firebase.google.com/docs/auth/flutter/password-auth](https://firebase.google.com/docs/auth/flutter/password-auth)

1. Enable **Email/Password** in the providers list
2. Use available methods to enable the flow
    - `loginWithEmail({required String email, required String password})`
    - `createAccountWithEmail({required String email, required String password})`
    - `sendResetPasswordLink(String email)`
    - `validatePassword(String password)`
    - `updatePassword(String password)`
    - `updateEmail(String email)`
    - `updateDisplayName(String displayName)`
    - `updatePhotoURL(String photoUrl)`

### Integrate anonymous authentication
💡 More info about this authentication here: [https://firebase.google.com/docs/auth/flutter/anonymous-auth](https://firebase.google.com/docs/auth/flutter/anonymous-auth)

1. Enable **Anonymous** in the providers list
2. Use `loginAnonymously()` to enable the flow

### Logout
1. No matter which authentication process the user used, simply use `Future logout()` to logout. 
2. Clean the user data you might have stored (database, settings...) to start fresh. 

## Troubleshooting

### App is crashing on iOS when using `signInWithGoogle`

Make sure you enabled Google provider on your Firebase App > Authentication.

Then, make sure you followed [the iOS integration](https://pub.dev/packages/google_sign_in_ios#ios-integration) and included required keys in `ios/Runner/Info.plist`.

You need to have the following configuration: 

```
<!-- Google Signin Configuration -->
<key>GIDClientID</key>
<string>[YOUR IOS CLIENT ID]</string>
<key>CFBundleURLTypes</key>
  <array>
      <dict>
          <key>CFBundleTypeRole</key>
          <string>Editor</string>
          <key>CFBundleURLSchemes</key>
          <array>
              <!-- TODO Replace this value: -->
              <!-- Copied from GoogleService-Info.plist key REVERSED_CLIENT_ID -->
              <string>com.googleusercontent.apps.[REVERSED_CLIENT_ID]</string>
          </array>
    </dict>
  </array>
<!-- @END Google Signin Configuration -->
```

### App is crashing on iOS when using `signInWithFacebook`

Make sure you enabled Facebook provider on your Firebase App > Authentication.

Then, make sure you followed [the iOS integration](https://facebook.meedu.app/docs/6.x.x/ios) and included required keys in `ios/Runner/Info.plist`.

You need to have the following configuration: 

```
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>fb{your-app-id}</string>
    </array>
  </dict>
</array>
<key>FacebookAppID</key>
<string>{your-app-id}</string>
<key>FacebookClientToken</key>
<string>CLIENT-TOKEN</string>
<key>FacebookDisplayName</key>
<string>{your-app-name}</string>
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>fbapi</string>
  <string>fb-messenger-share-api</string>
</array>
```

### How do I configure `CFBundleURLSchemes` in `ios/Runner/Info.plist` when using both Facebook and Google? 

You should merge values in Info.plist, instead of adding a duplicate key.

```
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>fb{your-app-id}</string>
      <string>com.googleusercontent.apps.[REVERSED_CLIENT_ID]</string>
    </array>
  </dict>
</array>
```

### Google Signin is failing on Android

Make sure you enabled Google provider on your Firebase App > Authentication.

The following message might appear: `PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10:, null, null)`. 

To solve that, make sure you added correctly the SHA1 or SHA256 signature of your app in the Android app configuration in Firebase. 

More info here: [https://developers.google.com/android/guides/client-auth](https://developers.google.com/android/guides/client-auth). 

⚠️ Debug and prod build have different SHA signatures.


## Future Development

- [ ] Add functionality to set the logger or use a default one
- [ ] Add the codes thrown from the service into the readme
- [ ] Add option to throw exceptions instead of returning a `FirebaseAuthenticationResult`
- [x] Add example to the package
- [x] Add a proper readme
- [x] Add examples into the readme
- [ ] Add mobile authentication option (implementation already exists, it just needs to be moved in here)
- [ ] Add other authentication providers

### Breaking Changes

- 2.20.0: Add `flutter_facebook_auth` dependency and its implementation
- 0.2.1: Removed `flutter_facebook_auth` dependency and its implementation since it was causing a `MissingPluginException` if the app isn't setup for Facebook Auth

ℹ️ For the full changelog, see [CHANGELOG.md](CHANGELOG.md). 