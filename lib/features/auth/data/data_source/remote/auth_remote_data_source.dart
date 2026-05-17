import 'dart:io';

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
}

class AuthRemoteSourceImpl implements AuthRemoteSource {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── Email Sign In ────────────────────────────────────────────
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
      if (response.user == null) throw Exception('Sign in failed');
      await _upsertUser(response.user!);
      return UserModel.fromSupabaseUser(response.user!.toJson());
    } catch (e) {
      throw Exception('Email sign in failed: $e');
    }
  }

  // ─── Email Sign Up ────────────────────────────────────────────
  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    File? avatarFile,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) throw Exception('Sign up failed');

      final userId = response.user!.id;
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

      return UserModel.fromSupabaseUser(response.user!.toJson()).copyWith(
        name: name,
        phone: phone,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      throw Exception('Email sign up failed: $e');
    }
  }

  // ─── Google Sign In/Up ────────────────────────────────────────
  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '304793073372-hct1k83vbefg4nthg942bbiuj38mjlha.apps.googleusercontent.com',
        scopes: ['email'],
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign in cancelled');

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) throw Exception('No ID token found');

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      if (response.user == null) throw Exception('Sign in failed');

      await _upsertUser(response.user!);
      return UserModel.fromSupabaseUser(response.user!.toJson());
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  // ─── Facebook Sign In/Up ──────────────────────────────────────
  @override
  Future<UserModel> signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (result.status != LoginStatus.success) {
        throw Exception('Facebook sign in cancelled');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.facebook,
        idToken: result.accessToken!.tokenString,
      );
      if (response.user == null) throw Exception('Sign in failed');

      await _upsertUser(response.user!);
      return UserModel.fromSupabaseUser(response.user!.toJson());
    } catch (e) {
      throw Exception('Facebook sign in failed: $e');
    }
  }

  // ─── Complete Profile (بعد Google/Facebook) ───────────────────
  @override
  Future<UserModel> completeProfile({
    required String userId,
    required String phone,
    File? avatarFile,
  }) async {
    try {
      String? avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await _uploadAvatar(userId, avatarFile);
      }

      await _supabase.from('users').update({
        'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', userId);

      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not found');

      return UserModel.fromSupabaseUser(user.toJson()).copyWith(
        phone: phone,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      throw Exception('Complete profile failed: $e');
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────
  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await FacebookAuth.instance.logOut();
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // ─── Get Current User ─────────────────────────────────────────
  @override
  UserModel? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return UserModel.fromSupabaseUser(user.toJson());
  }

  // ─── Upload Avatar ────────────────────────────────────────────
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
      return null;
    }
  }

  // ─── Upsert User ──────────────────────────────────────────────
  Future<void> _upsertUser(User user) async {
    final metadata = user.userMetadata ?? {};
    await _supabase.from('users').upsert({
      'id': user.id,
      'name': metadata['full_name'] ?? metadata['name'],
      'email': user.email,
      'avatar_url': metadata['avatar_url'] ?? metadata['picture'],
      'is_banned': false,
    });
  }
}