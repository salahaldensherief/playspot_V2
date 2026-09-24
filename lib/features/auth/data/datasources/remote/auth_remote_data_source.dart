import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:playspot/features/auth/domain/strategies/auth_context.dart';
import 'package:playspot/features/auth/domain/strategies/auth_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../art_core/exceptions/app_exceptions.dart';
import '../../../../../core/services/social_auth_service.dart';
import '../../../../../core/services/supabase_storage_service.dart';
import '../../models/auth_params.dart';
import '../../models/user_model.dart';

abstract class AuthRemoteSource {
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserModel> signUpWithEmail(SignUpParams params);

  Future<UserModel> verifySignupOTP({
    required String email,
    required String otp,
    required SignUpParams params,
  });

  Future<void> resendSignupOTP(String email);

  Future<UserModel> signInWithGoogle();

  Future<UserModel> signInWithFacebook();

  Future<UserModel> completeProfile(CompleteProfileParams params);

  Future<void> signOut();

  UserModel? getCurrentUser();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> verifyPasswordResetOTP({
    required String email,
    required String otp,
  });

  Future<void> resetPassword(String newPassword);

  Future<void> deleteAccount();
}

class AuthRemoteSourceImpl implements AuthRemoteSource {
  final SupabaseClient _supabase;
  final StorageService _storageService;
  final SocialAuthService _socialAuthService;
  final AuthContext _authContext;

  AuthRemoteSourceImpl(
    this._supabase,
    this._storageService,
    this._socialAuthService,
    this._authContext,
  );

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

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _authContext.authenticate(
      provider: AuthProviderType.email,
      credentials: {'email': email, 'password': password},
    );
  }

  @override
  Future<UserModel> signUpWithEmail(SignUpParams params) async {
    try {
      final response = await _supabase.auth.signUp(
        email: params.email,
        password: params.password,
      );
      if (response.user == null) throw const ServerException('Sign up failed');

      final userId = response.user!.id;

      // If session is null, Supabase requires email OTP verification before active login.
      if (response.session == null) {
        return UserModel(
          id: userId,
          email: params.email,
          name: params.name,
          phone: params.phone,
          isRequiresOtp: true,
        );
      }

      String? avatarUrl;
      if (params.avatarFile != null) {
        final fileExt = params.avatarFile!.path.split('.').last;
        avatarUrl = await _storageService.uploadFile(
          bucket: 'avatars',
          path: 'avatars/$userId.$fileExt',
          file: params.avatarFile!,
        );
      }

      await _supabase.from('profiles').upsert({
        'id': userId,
        'full_name': params.name,
        'email': params.email,
        'phone': params.phone,
        'avatar_url': avatarUrl,
      });

      if (params.referralCode != null &&
          params.referralCode!.trim().isNotEmpty) {
        try {
          await _supabase.rpc(
            'process_referral',
            params: {
              'p_referral_code': params.referralCode!.trim(),
              'p_new_user_id': userId,
            },
          );
        } catch (_) {
          try {
            final referrer = await _supabase
                .from('profiles')
                .select('id')
                .eq('referral_code', params.referralCode!.trim())
                .maybeSingle();

            if (referrer != null) {
              await _supabase.from('referrals').insert({
                'referrer_id': referrer['id'],
                'referred_id': userId,
              });
            }
          } catch (e) {
            debugPrint(' [Referral] Error processing referral: $e');
          }
        }
      }

      return UserModel.fromSupabaseUser(
        response.user!.toJson(),
        isNewUser: false,
      ).copyWith(name: params.name, phone: params.phone, avatarUrl: avatarUrl);
    } on AuthException catch (e) {
      if (e.message.contains('already registered') ||
          e.message.contains('already in use')) {
        throw const EmailAlreadyInUseException();
      }
      throw AppException(_parseAuthExceptionMessage(e), code: e.statusCode);
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  @override
  Future<UserModel> verifySignupOTP({
    required String email,
    required String otp,
    required SignUpParams params,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.signup,
      );
      final user = response.user ?? _supabase.auth.currentUser;
      if (user == null) throw const ServerException('OTP Verification failed');

      final userId = user.id;
      String? avatarUrl;
      if (params.avatarFile != null) {
        final fileExt = params.avatarFile!.path.split('.').last;
        avatarUrl = await _storageService.uploadFile(
          bucket: 'avatars',
          path: 'avatars/$userId.$fileExt',
          file: params.avatarFile!,
        );
      }

      await _supabase.from('profiles').upsert({
        'id': userId,
        'full_name': params.name,
        'email': params.email,
        'phone': params.phone,
        'avatar_url': avatarUrl,
      });

      if (params.referralCode != null &&
          params.referralCode!.trim().isNotEmpty) {
        try {
          await _supabase.rpc(
            'process_referral',
            params: {
              'p_referral_code': params.referralCode!.trim(),
              'p_new_user_id': userId,
            },
          );
        } catch (_) {
          try {
            final referrer = await _supabase
                .from('profiles')
                .select('id')
                .eq('referral_code', params.referralCode!.trim())
                .maybeSingle();

            if (referrer != null) {
              await _supabase.from('referrals').insert({
                'referrer_id': referrer['id'],
                'referred_id': userId,
              });
            }
          } catch (e) {
            debugPrint(' [Referral] Error processing referral: $e');
          }
        }
      }

      return UserModel.fromSupabaseUser(
        user.toJson(),
        isNewUser: false,
      ).copyWith(name: params.name, phone: params.phone, avatarUrl: avatarUrl);
    } on AuthException catch (e) {
      throw AppException(_parseAuthExceptionMessage(e), code: e.statusCode);
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  @override
  Future<void> resendSignupOTP(String email) async {
    try {
      await _supabase.auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      throw AppException(_parseAuthExceptionMessage(e), code: e.statusCode);
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  @override
  Future<UserModel> signInWithGoogle() {
    return _authContext.authenticate(provider: AuthProviderType.google);
  }

  @override
  Future<UserModel> signInWithFacebook() {
    return _authContext.authenticate(provider: AuthProviderType.facebook);
  }

  @override
  Future<UserModel> completeProfile(CompleteProfileParams params) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw const UserNotFoundException();
      final userId = params.userId.isNotEmpty ? params.userId : user.id;

      String? avatarUrl;
      if (params.avatarFile != null) {
        final fileExt = params.avatarFile!.path.split('.').last;
        avatarUrl = await _storageService.uploadFile(
          bucket: 'avatars',
          path: 'avatars/$userId.$fileExt',
          file: params.avatarFile!,
        );
      }

      final metadata = user.userMetadata ?? {};
      final fullName =
          metadata['full_name'] ??
          metadata['name'] ??
          user.email?.split('@').first ??
          '';

      final currentAvatarUrl =
          metadata['avatar_url'] as String? ?? metadata['picture'] as String?;
      final finalAvatarUrl = avatarUrl ?? currentAvatarUrl;

      // Save profile to profiles table - throw if saving fails
      await _supabase.from('profiles').upsert({
        'id': userId,
        'full_name': fullName,
        'email': user.email,
        'phone': params.phone,
        if (finalAvatarUrl != null) 'avatar_url': finalAvatarUrl,
      });

      try {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              'phone': params.phone,
              if (finalAvatarUrl != null) 'avatar_url': finalAvatarUrl,
            },
          ),
        );
      } catch (e) {
        debugPrint('[Auth] Error updating Auth user metadata: $e');
      }

      final updatedUser = UserModel.fromSupabaseUser(user.toJson()).copyWith(
        id: userId,
        phone: params.phone,
        avatarUrl: finalAvatarUrl,
        isNewUser: false,
      );

      return updatedUser;
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _socialAuthService.googleSignOut();
      await _socialAuthService.facebookSignOut();
      await _supabase.auth.signOut();
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  @override
  UserModel? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return UserModel.fromSupabaseUser(user.toJson());
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final cleanEmail = email.trim();
      debugPrint(' [Auth] Sending reset email to: $cleanEmail');
      await _supabase.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: 'com.playspot.client://login-callback',
      );
      debugPrint(' [Auth] Password reset email request sent successfully');
    } on AuthException catch (e, stackTrace) {
      debugPrint(
        ' [Auth] AuthException sending reset email: ${e.message} (code: ${e.code}, status: ${e.statusCode})',
      );
      debugPrintStack(stackTrace: stackTrace);
      String msg = e.message;
      if (e.message.contains('unexpected_failure') ||
          e.message.contains('Error sending recovery email')) {
        msg =
            'Failed to send recovery email. Please check your Supabase SMTP configuration or rate limit.';
      }
      throw AppException(msg, code: e.statusCode);
    } catch (e, stackTrace) {
      debugPrint(' [Auth] Unexpected error sending reset email: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw AppException(
        'An unexpected error occurred while sending the code.',
      );
    }
  }

  @override
  Future<void> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    try {
      debugPrint(' [Auth] Verifying recovery OTP for: $email');
      await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );
    } on AuthException catch (e) {
      debugPrint(' [Auth] AuthException verifying OTP: ${e.message}');
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      debugPrint(' [Auth] Unexpected error verifying OTP: $e');
      throw AppException('Invalid or expired code.');
    }
  }

  @override
  Future<void> resetPassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      debugPrint(' [Auth] Calling delete-account Edge Function...');
      try {
        await _supabase.functions.invoke('delete-account');
      } catch (e) {
        debugPrint(
          ' [Auth] Edge Function delete-account error ($e), falling back to RPC...',
        );
        await _supabase.rpc('delete_user_account');
      }
      debugPrint(' [Auth] Account deletion executed successfully.');
      await signOut();
      debugPrint(' [Auth] Signed out after deletion.');
    } on AuthException catch (e) {
      debugPrint(' [Auth] AuthException during deletion: ${e.message}');
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      debugPrint(' [Auth] Unexpected error during deletion: $e');
      throw AppException(e.toString());
    }
  }
}
