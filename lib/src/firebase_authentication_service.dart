import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'constants.dart';

/// Wraps the firebase auth functionality into a service
class FirebaseAuthenticationService {
  /// An Instance of Logger that can be used to log out what's happening in the service
  final Logger? log;

  final firebaseAuth = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;

  FirebaseAuthenticationService({
    @Deprecated(
        'Pass in the appleRedirectUri through the signInWithApple function')
    String? appleRedirectUri,
    @Deprecated(
        'Pass in the appleClientId through the signInWithApple function')
    String? appleClientId,
    this.log,
  });

  String? _mobileVerificationId;
  AuthCredential? _pendingCredential;

  Future<UserCredential> _signInWithCredential(
    AuthCredential credential,
  ) async {
    return await firebaseAuth.signInWithCredential(credential);
  }

  /// Returns the current logged in Firebase User
  User? get currentUser {
    return firebaseAuth.currentUser;
  }

  /// Returns the latest userToken stored in the Firebase Auth lib
  Future<String?>? get userToken {
    return firebaseAuth.currentUser?.getIdToken();
  }

  /// Returns true when a user has logged in or signed on this device
  bool get hasUser {
    return firebaseAuth.currentUser != null;
  }

  /// Exposes the authStateChanges functionality.
  Stream<User?> get authStateChanges {
    return firebaseAuth.authStateChanges();
  }

  /// Returns `true` when email has a user registered
  Future<bool> emailExists(String email) async {
    try {
      final signInMethods =
          await firebaseAuth.fetchSignInMethodsForEmail(email);

      return signInMethods.length > 0;
    } on FirebaseAuthException catch (e) {
      return e.code.toLowerCase() == 'invalid-email';
    }
  }

  /// Authenticates a user through Firebase using Google Provider.
  ///
  /// Supported platforms:
  ///   - Android
  ///   - iOS
  ///   - Web
  Future<FirebaseAuthenticationResult> signInWithGoogle(
      {String? webLoginHint, List<String>? scopes}) async {
    try {
      UserCredential userCredential;

      /// On the web, the Firebase SDK provides support for automatically
      /// handling the authentication flow.
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters(
            {'login_hint': webLoginHint ?? 'user@example.com'});
        (scopes ?? []).forEach(googleProvider.addScope);
        userCredential = await FirebaseAuth.instance.signInWithPopup(
          googleProvider,
        );
      }

      /// On native platforms, a 3rd party library, like GoogleSignIn, is
      /// required to trigger the authentication flow.
      else {
        _googleSignIn = GoogleSignIn(scopes: scopes ?? []);
        final GoogleSignInAccount? googleSignInAccount =
            await _googleSignIn!.signIn();
        if (googleSignInAccount == null) {
          log?.i('Process is canceled by the user');
          return FirebaseAuthenticationResult.error(
            errorMessage: 'Google Sign In has been canceled by the user',
            exceptionCode: 'canceled',
          );
        }
        final GoogleSignInAuthentication googleSignInAuthentication =
            await googleSignInAccount.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );

        userCredential = await _signInWithCredential(credential);
      }

      // Link the pending credential with the existing account
      if (_pendingCredential != null) {
        await userCredential.user?.linkWithCredential(_pendingCredential!);
        _clearPendingData();
      }

      return FirebaseAuthenticationResult(
        user: userCredential.user,
        additionalUserInfo: userCredential.additionalUserInfo,
        oAuthAccessToken: userCredential.credential?.accessToken,
      );
    } on FirebaseAuthException catch (e) {
      log?.e(e);
      return FirebaseAuthenticationResult.error(
        errorMessage: getErrorMessageFromFirebaseException(e),
        exceptionCode: e.code,
      );
    } catch (e) {
      log?.e(e);
      return FirebaseAuthenticationResult.error(errorMessage: e.toString());
    }
  }

  /// Authenticates a user through Firebase using Facebook Provider.
  ///
  /// Supported platforms:
  ///   - Android
  ///   - iOS
  ///   - Web
  Future<FirebaseAuthenticationResult> signInWithFacebook(
      {String? webLoginHint}) async {
    try {
      UserCredential userCredential;

      /// On the web, the Firebase SDK provides support for automatically
      /// handling the authentication flow.
      if (kIsWeb) {
        FacebookAuthProvider facebookProvider = FacebookAuthProvider();
        facebookProvider.setCustomParameters(
            {'login_hint': webLoginHint ?? 'user@example.com'});

        userCredential = await FirebaseAuth.instance.signInWithPopup(
          facebookProvider,
        );
      }

      /// On native platforms, a 3rd party library, like FacebookSignIn, is
      /// required to trigger the authentication flow.
      else {
        final LoginResult facebookLoginResult =
            await FacebookAuth.instance.login();
        if (facebookLoginResult.status == LoginStatus.cancelled) {
          log?.i('Process is canceled by the user');
          return FirebaseAuthenticationResult.error(
            errorMessage: 'Facebook Sign In has been canceled by the user',
            exceptionCode: 'canceled',
          );
        } else if (facebookLoginResult.status == LoginStatus.failed) {
          log?.i('Login failed with error: ${facebookLoginResult.message}');
          return FirebaseAuthenticationResult.error(
            errorMessage:
                'Facebook Sign In has failed with error: ${facebookLoginResult.message}',
            exceptionCode: 'failed',
          );
        }

        final OAuthCredential facebookAuthCredential =
            FacebookAuthProvider.credential(
                facebookLoginResult.accessToken!.token);

        userCredential = await _signInWithCredential(facebookAuthCredential);
      }

      // Link the pending credential with the existing account
      if (_pendingCredential != null) {
        await userCredential.user?.linkWithCredential(_pendingCredential!);
        _clearPendingData();
      }

      return FirebaseAuthenticationResult(
        user: userCredential.user,
        additionalUserInfo: userCredential.additionalUserInfo,
      );
    } on FirebaseAuthException catch (e) {
      log?.e(e);
      return FirebaseAuthenticationResult.error(
        errorMessage: getErrorMessageFromFirebaseException(e),
        exceptionCode: e.code,
      );
    } catch (e) {
      log?.e(e);
      return FirebaseAuthenticationResult.error(errorMessage: e.toString());
    }
  }

  Future<bool> isAppleSignInAvailable() async {
    return await SignInWithApple.isAvailable();
  }

  /// Apple will reject your app if you ask for the name when you sign in, but do not use it in the app.
  /// To prevent this, set askForFullName to false.
  Future<FirebaseAuthenticationResult> signInWithApple({
    required String? appleRedirectUri,
    required String? appleClientId,
    bool askForFullName = true,
  }) async {
    try {
      if (appleClientId == null) {
        throw FirebaseAuthException(
          message:
              'If you want to use Apple Sign In you have to provide a appleClientId to the FirebaseAuthenticationService',
          code: StackedFirebaseAuthAppleClientIdMissing,
        );
      }

      if (appleRedirectUri == null) {
        throw FirebaseAuthException(
          message:
              'If you want to use Apple Sign In you have to provide a appleRedirectUri to the FirebaseAuthenticationService',
          code: StackedFirebaseAuthAppleClientIdMissing,
        );
      }

      // To prevent replay attacks with the credential returned from Apple, we
      // include a nonce in the credential request. When signing in in with
      // Firebase, the nonce in the id token returned by Apple, is expected to
      // match the sha256 hash of `rawNonce`.
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      final appleIdCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          if (askForFullName) AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: appleClientId,
          redirectUri: Uri.parse(appleRedirectUri),
        ),
        nonce: nonce,
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleIdCredential.identityToken,
        accessToken: appleIdCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      final appleCredential = await _signInWithCredential(credential);

      // Link the pending credential with the existing account
      if (_pendingCredential != null) {
        await appleCredential.user?.linkWithCredential(_pendingCredential!);

        _clearPendingData();
      }

      if (askForFullName) {
        // Update the display name using the name from
        final givenName = appleIdCredential.givenName;
        final hasGivenName = givenName != null;
        final familyName = appleIdCredential.familyName;
        final hasFamilyName = familyName != null;

        // print('Apple Sign in complete: ${appleIdCredential.toString()}');

        await appleCredential.user?.updateDisplayName(
            '${hasGivenName ? givenName : ''}${hasFamilyName ? ' $familyName' : ''}');
      }

      return FirebaseAuthenticationResult(user: appleCredential.user);
    } on FirebaseAuthException catch (e) {
      log?.e(e);
      return FirebaseAuthenticationResult.error(
        errorMessage: getErrorMessageFromFirebaseException(e),
        exceptionCode: e.code,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      return FirebaseAuthenticationResult.error(
        errorMessage: e.toString(),
        exceptionCode: e.code.name,
      );
    } catch (e) {
      log?.e(e);
      return FirebaseAuthenticationResult.error(errorMessage: e.toString());
    }
  }

  /// Anonymous Login
  Future<FirebaseAuthenticationResult> loginAnonymously() async {
    try {
      log?.d('Anonymous Login');
      final result = await firebaseAuth.signInAnonymously();

      return FirebaseAuthenticationResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      log?.e('A firebase exception has occurred. $e');
      return FirebaseAuthenticationResult.error(
          exceptionCode: e.code.toLowerCase(),
          errorMessage: getErrorMessageFromFirebaseException(e));
    } on Exception catch (e) {
      log?.e('A general exception has occurred. $e');
      return FirebaseAuthenticationResult.error(
          errorMessage:
              'We could not log into your account at this time. Please try again.');
    }
  }

  Future<FirebaseAuthenticationResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      log?.d('email:$email');
      final result = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      log?.d('Sign in with email result: ${result.credential} ${result.user}');

      // Link the pending credential with the existing account
      if (_pendingCredential != null) {
        await result.user?.linkWithCredential(_pendingCredential!);
        _clearPendingData();
      }

      return FirebaseAuthenticationResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      log?.e('A firebase exception has occurred. $e');
      return FirebaseAuthenticationResult.error(
          exceptionCode: e.code.toLowerCase(),
          errorMessage: getErrorMessageFromFirebaseException(e));
    } on Exception catch (e) {
      log?.e('A general exception has occurred. $e');
      return FirebaseAuthenticationResult.error(
          errorMessage:
              'We could not log into your account at this time. Please try again.');
    }
  }

  /// Uses `createUserWithEmailAndPassword` to sign up to the Firebase application
  Future<FirebaseAuthenticationResult> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      log?.d('email:$email');
      final result = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      log?.d(
          'Create user with email result: ${result.credential} ${result.user}');

      return FirebaseAuthenticationResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      log?.e('A firebase exception has occurred. $e');
      return FirebaseAuthenticationResult.error(
          exceptionCode: e.code.toLowerCase(),
          errorMessage: getErrorMessageFromFirebaseException(e));
    } on Exception catch (e) {
      log?.e('A general exception has occurred. $e');
      return FirebaseAuthenticationResult.error(
          errorMessage:
              'We could not create your account at this time. Please try again.');
    }
  }

  /// Phone Number Login
  ///
  /// Web Platform support
  Future<ConfirmationResult> signInWithPhoneNumber(String phoneNumber) async {
    try {
      return firebaseAuth.signInWithPhoneNumber(phoneNumber);
    } catch (e) {
      throw FirebaseAuthenticationResult.error(
        errorMessage:
            'We could not send a verification code to your phone number. Please try again.',
        exceptionCode: e.toString(),
      );
    }
  }

  /// Verify SMS code using [confirmationResult] and [otp]
  ///
  /// Web Platform support
  Future<FirebaseAuthenticationResult> verifyOtp(
      ConfirmationResult confirmationResult, String otp) async {
    try {
      UserCredential userCredential = await confirmationResult.confirm(otp);
      return FirebaseAuthenticationResult(user: userCredential.user);
    } catch (e) {
      throw FirebaseAuthenticationResult.error(
        errorMessage:
            'We could not verify the otp at this time. Please try again.',
        exceptionCode: e.toString(),
      );
    }
  }

  /// Request a SMS verification code for [phoneNumber] sign-in.
  ///
  /// Native Platform support
  Future<void> requestVerificationCode({
    required String phoneNumber,
    void Function(FirebaseAuthenticationResult authenticationResult)?
        onVerificationCompleted,
    void Function(FirebaseAuthException exception)? onVerificationFailed,
    void Function(String verificationId)? onCodeSent,
    void Function(String verificationId)? onCodeTimeout,
    String? autoRetrievedSmsCodeForTesting,
    Duration timeout = const Duration(seconds: 30),
    int? forceResendingToken,
  }) async {
    await firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,

      /// Automatic handling of the SMS code on Android devices.
      verificationCompleted: (PhoneAuthCredential phoneAuthCredential) async {
        final userCredential = await firebaseAuth.signInWithCredential(
          phoneAuthCredential,
        );

        onVerificationCompleted?.call(
          FirebaseAuthenticationResult(user: userCredential.user),
        );
      },

      /// Handle failure events such as invalid phone numbers or whether the SMS
      /// quota has been exceeded.
      verificationFailed: (FirebaseAuthException firebaseAuthException) {
        onVerificationFailed?.call(firebaseAuthException);
      },

      /// Handle when a code has been sent to the device from Firebase, used to
      /// prompt users to enter the code.
      codeSent: (String verificationId, int? resendToken) async {
        _mobileVerificationId = verificationId;
        onCodeSent?.call(verificationId);
      },

      /// Handle a timeout of when automatic SMS code handling fails.
      codeAutoRetrievalTimeout: (String verificationId) {
        _mobileVerificationId = verificationId;
        onCodeTimeout?.call(verificationId);
      },
      forceResendingToken: forceResendingToken,
      timeout: timeout,
    );
  }

  /// Authenticate the user using SMS code [otp]
  ///
  /// Native Platform support
  Future<FirebaseAuthenticationResult> authenticateWithOtp(String otp) async {
    if (_mobileVerificationId == null) {
      throw 'The _mobileVerificationId should not be null here. Verification was probably skipped.';
    }

    try {
      final phoneAuthCredential = PhoneAuthProvider.credential(
        verificationId: _mobileVerificationId!,
        smsCode: otp,
      );

      final userCredential = await firebaseAuth.signInWithCredential(
        phoneAuthCredential,
      );

      return FirebaseAuthenticationResult(user: userCredential.user);
    } on FirebaseAuthException catch (e) {
      log?.e('A Firebase exception has occurred. $e');
      return FirebaseAuthenticationResult.error(
        exceptionCode: e.code.toLowerCase(),
        errorMessage: getErrorMessageFromFirebaseException(e),
      );
    } on Exception catch (e) {
      log?.e('A general exception has occurred. $e');
      return FirebaseAuthenticationResult.error(
        errorMessage:
            'We could not authenticate with OTP at this time. Please try again.',
      );
    }
  }

  /// Sign out of the social accounts that have been used
  Future logout() async {
    log?.i('logout');

    try {
      _clearPendingData();
      await firebaseAuth.signOut();
      await _googleSignIn?.signOut();
      await FacebookAuth.instance.logOut();
    } catch (e) {
      log?.e('Could not sign out of social account. $e');
    }
  }

  void _clearPendingData() {
    _pendingCredential = null;
  }

  /// Send reset password link to email
  Future sendResetPasswordLink(String email) async {
    log?.i('email:$email');

    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      log?.e('Could not send email with reset password link. $e');
      return false;
    }
  }

  /// Validate the current [password] of the Firebase User
  Future validatePassword(String password) async {
    try {
      final authCredentials = EmailAuthProvider.credential(
        email: firebaseAuth.currentUser?.email ?? '',
        password: password,
      );

      final authResult = await firebaseAuth.currentUser
          ?.reauthenticateWithCredential(authCredentials);

      return authResult?.user != null;
    } catch (e) {
      log?.e('Could not validate the user password. $e');
      return FirebaseAuthenticationResult.error(
          errorMessage: 'The current password is not valid.');
    }
  }

  /// Update the [password] of the Firebase User
  Future updatePassword(String password) async {
    await firebaseAuth.currentUser?.updatePassword(password);
  }

  /// Update the [email] of the Firebase User
  Future updateEmail(String email) async {
    await firebaseAuth.currentUser?.updateEmail(email);
  }

  /// Update the [displayName] of the Firebase User
  Future updateDisplayName(String displayName) async {
    await firebaseAuth.currentUser?.updateDisplayName(displayName);
  }

  /// Update the [photoURL] of the Firebase User
  Future updatePhotoURL(String photoUrl) async {
    await firebaseAuth.currentUser?.updatePhotoURL(photoUrl);
  }

  /// Generates a cryptographically secure random nonce, to be included in a
  /// credential request.
  String generateNonce([int length = 32]) {
    final charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class FirebaseAuthenticationResult {
  /// Firebase user
  final User? user;

  /// Firebase additional user information
  final AdditionalUserInfo? additionalUserInfo;
  final String? oAuthAccessToken;

  /// Contains the error message for the request
  final String? errorMessage;
  final String? exceptionCode;

  FirebaseAuthenticationResult(
      {this.user, this.additionalUserInfo, this.oAuthAccessToken})
      : errorMessage = null,
        exceptionCode = null;

  FirebaseAuthenticationResult.error({this.errorMessage, this.exceptionCode})
      : user = null,
        oAuthAccessToken = null,
        additionalUserInfo = null;

  /// Returns true if the response has an error associated with it
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

String getErrorMessageFromFirebaseException(FirebaseAuthException exception) {
  switch (exception.code.toLowerCase()) {
    case 'email-already-in-use':
      return 'An account already exists for the email you\'re trying to use. Login instead.';
    case 'invalid-email':
      return 'The email you\'re using is invalid. Please use a valid email.';
    case 'operation-not-allowed':
      return 'The authentication is not enabled on Firebase. Please enable the Authentitcation type on Firebase';
    case 'weak-password':
      return 'Your password is too weak. Please use a stronger password.';
    case 'wrong-password':
      return 'You seemed to have entered the wrong password. Double check it and try again.';
    default:
      return exception.message ??
          'Something went wrong on our side. Please try again';
  }
}
