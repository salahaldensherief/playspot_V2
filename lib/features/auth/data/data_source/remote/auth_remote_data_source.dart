import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../art_core/exceptions/app_exceptions.dart';
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
  final SupabaseClient _supabase = Supabase.instance.client;

  // Email Sign In
  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[Auth] Signing in with email: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) throw const ServerException('Sign in failed');
      debugPrint(' [Auth] Email sign in success: ${response.user!.id}');
      await _upsertUser(response.user!);
      return UserModel.fromSupabaseUser(response.user!.toJson());
    } on AuthException catch (e) {
      debugPrint(' [Auth] AuthException: ${e.message}');
      if (e.message.contains('Invalid login')) {
        throw const InvalidCredentialsException();
      }
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      debugPrint(' [Auth] Email sign in error: $e');
      throw AppException(e.toString());
    }
  }

  //  Email Sign Up
  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    File? avatarFile,
  }) async {
    try {
      debugPrint('[Auth] Signing up with email: $email');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) throw const ServerException('Sign up failed');

      final userId = response.user!.id;
      debugPrint(' [Auth] Sign up success: $userId');

      String? avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await _uploadAvatar(userId, avatarFile);
      }

      await _supabase.from('users').upsert({
        'id': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
        'is_banned': false,
      });

      debugPrint(' [Auth] User saved to DB');

      return UserModel.fromSupabaseUser(
        response.user!.toJson(),
        isNewUser: false,
      ).copyWith(name: name, phone: phone, avatarUrl: avatarUrl);
    } on AuthException catch (e) {
      debugPrint(' [Auth] AuthException: ${e.message}');
      if (e.message.contains('already registered')) {
        throw const EmailAlreadyInUseException();
      }
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      debugPrint(' [Auth] Email sign up error: $e');
      throw AppException(e.toString());
    }
  }

  // Google Sign In/Up
  @override
  // Google Sign In/Up
  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      debugPrint('🔵 [Auth] Starting Google sign in...');

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '304793073372-q1lo1lo8bvvget42ooevpduqvb5v4m6j.apps.googleusercontent.com',
        serverClientId:
        '304793073372-hct1k83vbefg4nthg942bbiuj38mjlha.apps.googleusercontent.com',
        scopes: ['email'],

      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw const GoogleSignInCancelledException();

      debugPrint('[Auth] Google user: ${googleUser.email}');

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) throw const ServerException('No ID token found');

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user == null) throw const ServerException('Sign in failed');

      debugPrint('[Auth] Google sign in success: ${response.user!.id}');

      final existingUser = await _supabase
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      final phone = existingUser?['phone'];
      final isNewUser = existingUser == null ||
          phone == null ||
          phone.toString().trim().isEmpty;
      debugPrint(' [Auth] Is new user: $isNewUser');

      await _upsertUser(response.user!);

      return UserModel.fromSupabaseUser(
        response.user!.toJson(),
        isNewUser: isNewUser,
      );
    } on AppException {
      rethrow;
    } on AuthException catch (e) {
      debugPrint(' [Auth] AuthException: ${e.message}');
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      debugPrint(' [Auth] Google sign in error: $e');
      throw AppException(e.toString());
    }
  }
  //Facebook Sign In/Up

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
  }  // Complete Profile
  @override
  Future<UserModel> completeProfile({
    required String userId,
    required String phone,
    File? avatarFile,
  }) async {
    try {
      debugPrint('[Auth] Completing profile for: $userId');

      String? avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await _uploadAvatar(userId, avatarFile);
      }

      await _supabase.from('users').update({
        'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', userId);

      debugPrint(' [Auth] Profile completed');

      final user = _supabase.auth.currentUser;
      if (user == null) throw const UserNotFoundException();

      return UserModel.fromSupabaseUser(user.toJson()).copyWith(
        phone: phone,
        avatarUrl: avatarUrl,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint(' [Auth] Complete profile error: $e');
      throw AppException(e.toString());
    }
  }

  //  Sign Out
  @override
  Future<void> signOut() async {
    try {
      debugPrint('[Auth] Signing out...');
      await GoogleSignIn().signOut();
      await FacebookAuth.instance.logOut();
      await _supabase.auth.signOut();
      debugPrint(' [Auth] Signed out successfully');
    } catch (e) {
      debugPrint(' [Auth] Sign out error: $e');
      throw AppException(e.toString());
    }
  }

  // Get Current User
  @override
  UserModel? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('[Auth] No current user');
      return null;
    }
    debugPrint('[Auth] Current user: ${user.id}');
    return UserModel.fromSupabaseUser(user.toJson());
  }

  // Send Password Reset Email
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('[Auth] Sending password reset email to: $email');
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      debugPrint(' [Auth] AuthException: ${e.message}');
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      debugPrint(' [Auth] Reset password error: $e');
      throw AppException(e.toString());
    }
  }

  // Verify Password Reset OTP
  @override
  Future<void> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    try {
      debugPrint('[Auth] Verifying reset password OTP for: $email');
      await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );
    } on AuthException catch (e) {
      debugPrint(' [Auth] AuthException: ${e.message}');
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      debugPrint(' [Auth] OTP verification error: $e');
      throw AppException(e.toString());
    }
  }

  // Reset Password
  @override
  Future<void> resetPassword(String newPassword) async {
    try {
      debugPrint('[Auth] Resetting password...');
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      debugPrint(' [Auth] AuthException: ${e.message}');
      throw AppException(e.message, code: e.statusCode);
    } catch (e) {
      debugPrint(' [Auth] Reset password error: $e');
      throw AppException(e.toString());
    }
  }

  // Upload Avatar
  Future<String?> _uploadAvatar(String userId, File avatarFile) async {
    try {
      final fileExt = avatarFile.path.split('.').last;
      final fileName = 'avatars/$userId.$fileExt';
      await _supabase.storage.from('avatars').upload(
        fileName,
        avatarFile,
        fileOptions: const FileOptions(upsert: true),
      );
      return _supabase.storage.from('avatars').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('[Auth] Avatar upload failed: $e');
      return null;
    }
  }

  // Upsert User
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
      debugPrint(' [Auth] User upserted: ${user.id}');
    } catch (e) {
      debugPrint('[Auth] Upsert user failed: $e');
    }
  }
}