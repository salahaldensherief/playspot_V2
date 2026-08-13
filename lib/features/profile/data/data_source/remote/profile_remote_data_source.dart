import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../art_core/exceptions/app_exceptions.dart';
import '../../../../../core/services/supabase_storage_service.dart';
import '../../../../auth/data/models/user_model.dart';
import '../../models/redemption_option_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    String? email,
    File? avatarFile,
  });
  UserModel? getCurrentUser();
  Future<int> getPointsBalance();
  Future<List<RedemptionOptionModel>> getRedemptionOptions();
  Future<Map<String, dynamic>> redeemPoints(String optionId);
  Future<List<Map<String, dynamic>>> getMyVouchers();
  Future<Map<String, dynamic>> validateVoucher(String voucherId);
  Future<void> consumeVoucher({required String voucherId, required String bookingId});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient _supabase;
  final StorageService _storageService;

  ProfileRemoteDataSourceImpl(this._supabase, this._storageService);

  @override
  Future<void> consumeVoucher({required String voucherId, required String bookingId}) async {
    await _supabase.rpc('consume_voucher', params: {
      'p_voucher_id': voucherId,
      'p_booking_id': bookingId,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getMyVouchers() async {
    try {
      final response = await _supabase.rpc('get_my_vouchers');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> validateVoucher(String voucherId) async {
    try {
      final response = await _supabase.rpc('validate_voucher', params: {
        'p_voucher_id': voucherId,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      return {'valid': false, 'error': e.toString()};
    }
  }

  @override
  Future<int> getPointsBalance() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;
      final response = await _supabase.rpc('get_user_points_balance', params: {
        'p_user_id': user.id,
      });
      return response as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<List<RedemptionOptionModel>> getRedemptionOptions() async {
    try {
      final response = await _supabase
          .from('redemption_options')
          .select()
          .eq('is_active', true);
      return (response as List)
          .map((e) => RedemptionOptionModel.fromJson(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> redeemPoints(String optionId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw const UserNotFoundException();
      final response = await _supabase.rpc('redeem_points', params: {
        'p_user_id': user.id,
        'p_redemption_option_id': optionId,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

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

      String? avatarUrl;
      if (avatarFile != null) {
        final fileExt = avatarFile.path.split('.').last;
        avatarUrl = await _storageService.uploadFile(
          bucket: 'avatars',
          path: 'avatars/$userId.$fileExt',
          file: avatarFile,
        );
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
}
