import '../datasources/remote/auth_profile_initializer.dart';
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
}
