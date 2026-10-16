import '../datasources/remote/auth_profile_initializer.dart';
import 'dart:async';
import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/strategies/auth_strategy.dart';
import '../models/user_model.dart';
import '../../../../art_core/exceptions/app_exceptions.dart';
import '../../../../core/services/social_auth_service.dart';

class GoogleAuthStrategy implements AuthStrategy {
  final SupabaseClient _supabase;
  final SocialAuthService _socialAuthService;

  GoogleAuthStrategy(this._supabase, this._socialAuthService);

  @override
  AuthProviderType get providerType => AuthProviderType.google;

  @override
  Future<UserModel> authenticate(Map<String, dynamic> credentials) async {
    late final User user;
    try {
      final idToken = await _socialAuthService.getGoogleIdToken();
      if (idToken == null) throw const GoogleSignInCancelledException();

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.user == null) throw const ServerException('Sign in failed');

      user = response.user!;
    } on GoogleSignInCancelledException {
      rethrow;
    } on AuthException catch (e) {
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      AppLogger.debug(
        '[Auth] Native Google Sign-In failed ($e). Falling back to Supabase OAuth...',
      );
      return await _signInWithSupabaseOAuth();
    }
    final isNewUser = await AuthProfileInitializer(
      _supabase,
    ).ensureProfile(user);
    return UserModel.fromSupabaseUser(user.toJson(), isNewUser: isNewUser);
  }

  Future<UserModel> _signInWithSupabaseOAuth() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.playspot.client://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      final completer = Completer<UserModel>();
      late final StreamSubscription subscription;
      subscription = _supabase.auth.onAuthStateChange.listen((data) async {
        if (data.event == AuthChangeEvent.signedIn && data.session != null) {
          final user = data.session!.user;
          final isNewUser = await AuthProfileInitializer(
            _supabase,
          ).ensureProfile(user);
          subscription.cancel();
          if (!completer.isCompleted) {
            completer.complete(
              UserModel.fromSupabaseUser(user.toJson(), isNewUser: isNewUser),
            );
          }
        }
      });

      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          subscription.cancel();
          throw const ServerException('Google sign in timeout');
        },
      );
    } catch (oauthErr) {
      if (oauthErr is AuthException) {
        throw AppException(oauthErr.message, code: oauthErr.statusCode);
      }
      throw AppException(oauthErr.toString());
    }
  }
}
