import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../../art_core/exceptions/app_exceptions.dart';

abstract class SocialAuthService {
  Future<String?> getGoogleIdToken();
  Future<void> facebookSignOut();
  Future<void> googleSignOut();
}

class SocialAuthServiceImpl implements SocialAuthService {
  @override
  Future<String?> getGoogleIdToken() async {
    try {
      debugPrint('[SocialAuth] Initializing Google Sign-In...');
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // We provide both because sometimes Android needs the explicit client ID 
        // if the google-services.json isn't being read correctly by the plugin.
        clientId: '304793073372-7eipb31om1ge4pn0rtkioecv8a3g5rvo.apps.googleusercontent.com',
        serverClientId: '304793073372-hct1k83vbefg4nthg942bbiuj38mjlha.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      // Trigger the authentication flow
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('[SocialAuth] User cancelled sign-in');
        return null;
      }

      debugPrint('[SocialAuth] User signed in: ${googleUser.email}');
      
      final googleAuth = await googleUser.authentication;
      
      if (googleAuth.idToken == null) {
        debugPrint('[SocialAuth] FAILED: ID Token is null. Check your SHA-1 and Package Name.');
        throw Exception('Could not get ID Token from Google');
      }

      return googleAuth.idToken;
    } catch (e) {
      debugPrint('[SocialAuth] Google Sign-in CRITICAL ERROR: $e');
      if (e.toString().contains('10')) {
        debugPrint('[SocialAuth] Tip: Ensure the Support Email is set in Google Cloud Console OAuth Consent Screen.');
      }
      rethrow;
    }
  }

  @override
  Future<void> googleSignOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  @override
  Future<void> facebookSignOut() async {
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
  }
}
