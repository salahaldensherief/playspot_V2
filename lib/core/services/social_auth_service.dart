import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

abstract class SocialAuthService {
  Future<String?> getGoogleIdToken();
  Future<void> facebookSignOut();
  Future<void> googleSignOut();
}

class SocialAuthServiceImpl implements SocialAuthService {
  static const String _serverClientId =
      '1070210806389-2a4mcuu9f2hdrvj82oemg06ftd2fbacd.apps.googleusercontent.com';

  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      try {
        debugPrint('[SocialAuth] Initializing GoogleSignIn.instance with serverClientId...');
        await GoogleSignIn.instance.initialize(
          serverClientId: _serverClientId,
        );
        _isInitialized = true;
      } catch (e) {
        debugPrint('[SocialAuth] GoogleSignIn initialize exception: $e');
      }
    }
  }

  @override
  Future<String?> getGoogleIdToken() async {
    try {
      debugPrint('[SocialAuth] Starting Google Sign-In...');

      await _ensureInitialized();

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      debugPrint('[SocialAuth] User signed in: ${googleUser.email}');

      final googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        debugPrint(
            '[SocialAuth] FAILED: ID Token is null. Check Web Client ID (_serverClientId) and SHA-1 fingerprint in Google Cloud Console.');
        throw Exception('Could not get ID Token from Google');
      }

      return googleAuth.idToken;
    } catch (e) {
      debugPrint('[SocialAuth] Google Sign-in Error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('cancel') || errStr.contains('user_canceled')) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> googleSignOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  @override
  Future<void> facebookSignOut() async {
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
  }
}
