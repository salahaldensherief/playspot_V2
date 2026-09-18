import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/strategies/auth_strategy.dart';
import '../models/user_model.dart';
import '../../../../art_core/exceptions/app_exceptions.dart';

class FacebookAuthStrategy implements AuthStrategy {
  final SupabaseClient _supabase;

  FacebookAuthStrategy(this._supabase);

  @override
  AuthProviderType get providerType => AuthProviderType.facebook;

  @override
  Future<UserModel> authenticate(Map<String, dynamic> credentials) async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'com.playspot.client://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      final completer = Completer<UserModel>();
      late final StreamSubscription subscription;
      subscription = _supabase.auth.onAuthStateChange.listen((data) async {
        if (data.event == AuthChangeEvent.signedIn && data.session != null) {
          final user = data.session!.user;
          final isNewUser = await _checkIsNewUser(user.id);
          await _upsertUser(user);
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
          throw const ServerException('Facebook sign in timeout');
        },
      );
    } catch (e) {
      if (e is AuthException) {
        throw AppException(e.message, code: e.statusCode);
      }
      throw AppException(e.toString());
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

  Future<void> _upsertUser(User user) async {
    final meta = user.userMetadata ?? {};
    await _supabase.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'full_name': meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'User',
      'avatar_url': meta['avatar_url'] ?? meta['picture'],
      'is_banned': false,
    });
  }
}
