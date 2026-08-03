import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../art_core/exceptions/app_exceptions.dart';
import '../../../../../core/services/supabase_storage_service.dart';
import '../../../../../core/services/social_auth_service.dart';
import '../../models/user_model.dart';

abstract class AuthRemoteSource {
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    File? avatarFile,
    String? referralCode,
  });
  Future<UserModel> signInWithGoogle();
  Future<UserModel> signInWithFacebook();
  Future<UserModel> completeProfile({
    required String userId,
    required String phone,
    File? avatarFile,
  });
  Future<void> signOut();
  UserModel? getCurrentUser();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> verifyPasswordResetOTP({
    required String email,
    required String otp,
  });
  Future<void> resetPassword(String newPassword);
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
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    File? avatarFile,
    String? referralCode,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) throw const ServerException('Sign up failed');

      final userId = response.user!.id;
      String? avatarUrl;
      if (avatarFile != null) {
        final fileExt = avatarFile.path.split('.').last;
        avatarUrl = await _storageService.uploadFile(
          bucket: 'avatars',
          path: 'avatars/$userId.$fileExt',
          file: avatarFile,
        );
      }

      await _supabase.from('users').upsert({
        'id': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
        'is_banned': false,
      });

      if (referralCode != null && referralCode.trim().isNotEmpty) {
        try {
          final referrer = await _supabase
              .from('users')
              .select('id')
              .eq('referral_code', referralCode.trim())
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
      ).copyWith(name: name, phone: phone, avatarUrl: avatarUrl);
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

      final existingUser = await _supabase
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      final phone = existingUser?['phone'];
      final isNewUser = existingUser == null ||
          phone == null ||
          phone.toString().trim().isEmpty;

      await _upsertUser(response.user!);

      return UserModel.fromSupabaseUser(
        response.user!.toJson(),
        isNewUser: isNewUser,
      );
    } on AppException {
      rethrow;
    } on AuthException catch (e) {
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppException(e.toString());
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
      _supabase.auth.onAuthStateChange.listen((data) async {
        if (data.event == AuthChangeEvent.signedIn && data.session != null) {
          final user = data.session!.user;
          await _upsertUser(user);
          completer.complete(UserModel.fromSupabaseUser(user.toJson()));
        }
      });

      return completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw const ServerException('Facebook sign in timeout'),
      );
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  @override
  Future<UserModel> completeProfile({
    required String userId,
    required String phone,
    File? avatarFile,
  }) async {
    try {
      String? avatarUrl;
      if (avatarFile != null) {
        final fileExt = avatarFile.path.split('.').last;
        avatarUrl = await _storageService.uploadFile(
          bucket: 'avatars',
          path: 'avatars/$userId.$fileExt',
          file: avatarFile,
        );
      }

      await _supabase.from('users').update({
        'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', userId);

      final user = _supabase.auth.currentUser;
      if (user == null) throw const UserNotFoundException();

      return UserModel.fromSupabaseUser(user.toJson()).copyWith(
        phone: phone,
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
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: null,
      );
    } on AuthException catch (e) {
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  @override
  Future<void> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    try {
      await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
    } on AuthException catch (e) {
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppException(e.toString());
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

  Future<void> _upsertUser(User user) async {
    try {
      final metadata = user.userMetadata ?? {};
      await _supabase.from('users').upsert({
        'id': user.id,
        'name': metadata['full_name'] ?? metadata['name'],
        'email': user.email,
        'avatar_url': metadata['avatar_url'] ?? metadata['picture'],
        'is_banned': false,
      });
    } catch (_) {}
  }
}
