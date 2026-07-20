import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../art_core/exceptions/app_exceptions.dart';
import '../../../../auth/data/models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    String? email,
    File? avatarFile,
  });
  UserModel? getCurrentUser();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient _supabase;

  ProfileRemoteDataSourceImpl(this._supabase);

  @override
  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    String? email,
    File? avatarFile,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw const UserNotFoundException();
      final userId = user.id;

      debugPrint('[Profile] Updating profile for: $userId');

      String? avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await _uploadAvatar(userId, avatarFile);
      }

      final updateData = {
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

      await _supabase.from('users').update(updateData).eq('id', userId);

      await _supabase.auth.updateUser(
        UserAttributes(
          email: email,
          data: {
            'full_name': name,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          },
        ),
      );

      debugPrint(' [Profile] Profile updated');

      return UserModel.fromSupabaseUser(_supabase.auth.currentUser!.toJson())
          .copyWith(
        name: name,
        phone: phone,
        avatarUrl: avatarUrl,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint(' [Profile] Update profile error: $e');
      throw AppException(e.toString());
    }
  }

  @override
  UserModel? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return UserModel.fromSupabaseUser(user.toJson());
  }

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
      debugPrint('[Profile] Avatar upload failed: $e');
      return null;
    }
  }
}
