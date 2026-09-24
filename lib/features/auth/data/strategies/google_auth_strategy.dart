import 'dart:async';
import 'package:flutter/foundation.dart';
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
    try {
      final idToken = await _socialAuthService.getGoogleIdToken();
      if (idToken == null) throw const GoogleSignInCancelledException();

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.user == null) throw const ServerException('Sign in failed');

      final user = response.user!;
      final isNewUser = await _checkIsNewUser(user.id);
      await _upsertUser(user, isNewUser: isNewUser);

      return UserModel.fromSupabaseUser(
        user.toJson(),
        isNewUser: isNewUser,
      );
    } on GoogleSignInCancelledException {
      rethrow;
    } on AuthException catch (e) {
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      debugPrint('[Auth] Native Google Sign-In failed ($e). Falling back to Supabase OAuth...');
      return _signInWithSupabaseOAuth();
    }
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
          final isNewUser = await _checkIsNewUser(user.id);
          await _upsertUser(user, isNewUser: isNewUser);
          subscription.cancel();
          if (!completer.isCompleted) {
            completer.complete(UserModel.fromSupabaseUser(
              user.toJson(),
              isNewUser: isNewUser,
            ));
          }
        }
      });

      return completer.future.timeout(
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

  Future<bool> _checkIsNewUser(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return response == null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _upsertUser(User user, {required bool isNewUser}) async {
    final meta = user.userMetadata ?? {};
    try {
      if (isNewUser) {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'email': user.email,
          'full_name': meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'User',
          'avatar_url': meta['avatar_url'] ?? meta['picture'],
        });
      } else {
        final updateData = <String, dynamic>{
          'email': user.email,
          'full_name': meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'User',
        };
        final avatar = meta['avatar_url'] ?? meta['picture'];
        if (avatar != null) {
          updateData['avatar_url'] = avatar;
        }
        await _supabase.from('profiles').update(updateData).eq('id', user.id);
      }
    } catch (e) {
      debugPrint('[Auth] Profile sync notice: $e');
      if (isNewUser) {
        rethrow;
      }
    }
  }
}
