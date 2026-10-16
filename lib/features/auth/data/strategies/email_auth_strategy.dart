import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/strategies/auth_strategy.dart';
import '../models/user_model.dart';
import '../../../../art_core/exceptions/app_exceptions.dart';
import '../datasources/remote/auth_profile_initializer.dart';

class EmailAuthStrategy implements AuthStrategy {
  final SupabaseClient _supabase;

  EmailAuthStrategy(this._supabase);

  @override
  AuthProviderType get providerType => AuthProviderType.email;

  @override
  Future<UserModel> authenticate(Map<String, dynamic> credentials) async {
    final email = credentials['email'] as String?;
    final password = credentials['password'] as String?;

    if (email == null || password == null) {
      throw const AppException('Email and password are required');
    }

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw const ServerException('Sign in failed');
      }

      final user = response.user!;
      final isNewUser = await AuthProfileInitializer(
        _supabase,
      ).ensureProfile(user);

      return UserModel.fromSupabaseUser(user.toJson(), isNewUser: isNewUser);
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login')) {
        throw const InvalidCredentialsException();
      }
      throw AppException(_parseAuthExceptionMessage(e), code: e.statusCode);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(e.toString());
    }
  }

  String _parseAuthExceptionMessage(AuthException e) {
    final msg = e.message;
    if (msg.contains('already registered') || msg.contains('already in use')) {
      return 'Email is already registered';
    }
    if (msg.contains('sending confirmation email') ||
        msg.contains('unexpected_failure')) {
      return 'Unable to send confirmation email. Please check your email address or try again.';
    }
    if (msg.startsWith('{') && msg.contains('"message":')) {
      try {
        final map = jsonDecode(msg) as Map<String, dynamic>;
        if (map.containsKey('message')) {
          return map['message'].toString();
        }
      } catch (_) {}
    }
    return msg;
  }
}
