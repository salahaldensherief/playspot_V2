import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../art_core/exceptions/app_exceptions.dart';
import '../../../../../core/services/supabase_storage_service.dart';
import '../../../../../core/services/social_auth_service.dart';
import '../../models/user_model.dart';
import '../../models/auth_params.dart';

abstract class AuthRemoteSource {
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });
  Future<UserModel> signUpWithEmail(SignUpParams params);
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

  AuthRemoteSourceImpl(
    this._supabase,
    this._storageService,
    this._socialAuthService,
  );

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) throw const ServerException('Sign in failed');
      await _upsertUser(response.user!);
      return UserModel.fromSupabaseUser(response.user!.toJson());
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login')) {
        throw const InvalidCredentialsException();
      }
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppException(e.toString());
    }
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
        'is_banned': false,
      });

      if (params.referralCode != null && params.referralCode!.trim().isNotEmpty) {
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

      return UserModel.fromSupabaseUser(
        response.user!.toJson(),
        isNewUser: false,
      ).copyWith(name: params.name, phone: params.phone, avatarUrl: avatarUrl);
    } on AuthException catch (e) {
      if (e.message.contains('already registered')) {
        throw const EmailAlreadyInUseException();
      }
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
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
      await _upsertUser(user);

      return UserModel.fromSupabaseUser(
        user.toJson(),
        isNewUser: isNewUser,
      );
    } on GoogleSignInCancelledException {
      rethrow;
    } catch (e) {
      debugPrint('[Auth] Native Google Sign-In failed ($e). Falling back to Supabase OAuth...');
      try {
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'com.playspot.app://login-callback',
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
            throw const ServerException('Google sign in timeout');
          },
        );
      } catch (oauthErr) {
        throw AppException(e.toString());
      }
    }
  }

  @override
  Future<UserModel> signInWithFacebook() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'com.playspot.app://login-callback',
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
      throw AppException(e.toString());
    }
  }

  @override
  Future<UserModel> completeProfile(CompleteProfileParams params) async {
    try {
      String? avatarUrl;
      if (params.avatarFile != null) {
        final fileExt = params.avatarFile!.path.split('.').last;
        avatarUrl = await _storageService.uploadFile(
          bucket: 'avatars',
          path: 'avatars/${params.userId}.$fileExt',
          file: params.avatarFile!,
        );
      }

      final updateData = <String, dynamic>{
        'phone': params.phone,
      };
      if (avatarUrl != null) {
        updateData['avatar_url'] = avatarUrl;
      }

      await _supabase.from('profiles').update(updateData).eq('id', params.userId);

      final user = _supabase.auth.currentUser;
      if (user == null) throw const UserNotFoundException();

      return UserModel.fromSupabaseUser(user.toJson()).copyWith(
        phone: params.phone,
        avatarUrl: avatarUrl,
      );
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
      debugPrint(' [Auth] Sending reset email to: $email');
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      debugPrint(' [Auth] AuthException sending reset email: ${e.message}');
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      debugPrint(' [Auth] Unexpected error sending reset email: $e');
      throw AppException('An unexpected error occurred while sending the code.');
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
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      debugPrint(' [Auth] Attempting to delete account via RPC...');
      await _supabase.rpc('delete_user_account');
      debugPrint(' [Auth] RPC delete_user_account executed successfully.');
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

  Future<bool> _checkIsNewUser(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('phone')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) return true;

      final phone = profile['phone'];
      final isPhoneMissing = phone == null || phone.toString().trim().isEmpty;

      return isPhoneMissing;
    } catch (e) {
      debugPrint('[Auth] Error checking isNewUser for $userId: $e');
      return true;
    }
  }

  Future<void> _upsertUser(User user) async {
    try {
      final metadata = user.userMetadata ?? {};
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('profiles').insert({
          'id': user.id,
          'full_name': metadata['full_name'] ?? metadata['name'],
          'email': user.email,
          'avatar_url': metadata['avatar_url'] ?? metadata['picture'],
          'is_banned': false,
        });
      }
    } catch (e) {
      debugPrint('[Auth] Error in _upsertUser: $e');
    }
  }
}
