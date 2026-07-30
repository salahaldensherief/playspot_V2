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
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '1070210806389-o8gnmeqe0bbritv4ckg14p5cdlqck165.apps.googleusercontent.com',
        serverClientId: '1070210806389-2a4mcuu9f2hdrvj82oemg06ftd2fbacd.apps.googleusercontent.com',
        scopes: ['email'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      return googleAuth.idToken;
    } catch (e) {
      debugPrint('[SocialAuth] Google Sign-in Error: $e');
      throw AppException(e.toString());
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
