import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/exceptions/app_exceptions.dart';
import '../../../../../core/models/paginated_response.dart';
import '../../../../../core/services/supabase_storage_service.dart';
import '../../../../auth/data/models/user_model.dart';
import '../../models/notification_settings_model.dart';
import '../../models/redemption_option_model.dart';
import '../../models/profile_params.dart';
import '../../models/loyalty_status_model.dart';
import '../../models/loyalty_mission_model.dart';
import '../../models/user_referral_stats_model.dart';
import '../../models/claim_referral_result.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> updateProfile(UpdateProfileParams params);
  UserModel? getCurrentUser();
  Future<UserModel> getUserProfile();
  Future<int> getPointsBalance();
  Future<PaginatedResponse<Map<String, dynamic>>> getPointsHistory({
    int page = 1,
    int pageSize = 20,
  });
  Future<List<RedemptionOptionModel>> getRedemptionOptions();
  Future<Map<String, dynamic>> redeemPoints(String optionId);
  Future<List<Map<String, dynamic>>> getMyVouchers();
  Future<Map<String, dynamic>> validateVoucher(String voucherId);
  Future<Map<String, dynamic>> validateVoucherByCode(String code);
  Future<void> consumeVoucher({required String voucherId, required String bookingId});
  Future<void> updateFcmToken(String token);
  Future<NotificationSettingsModel> getNotificationSettings();
  Future<void> updateNotificationSettings(NotificationSettingsModel settings);
  Future<LoyaltyStatusModel> getLoyaltyStatus();
  Future<List<LoyaltyMissionModel>> getLoyaltyMissions();
  Future<UserReferralStatsModel> getReferralStats();
  Future<ClaimReferralResult> claimReferralCode(String referralCode);
  Future<int> getTotalBookingsCount();
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
  Future<Map<String, dynamic>> validateVoucherByCode(String code) async {
    try {
      final response = await _supabase.rpc('validate_voucher_by_code', params: {
        'p_code': code,
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
  Future<PaginatedResponse<Map<String, dynamic>>> getPointsHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return PaginatedResponse(
          items: const [],
          totalCount: 0,
          page: page,
          pageSize: pageSize,
        );
      }
      try {
        final response = await _supabase.rpc('get_points_transactions_page', params: {
          'p_page': page,
          'p_page_size': pageSize,
        });
        return PaginatedResponse.fromRpc(
          response: response,
          fromJson: (json) => json,
          requestedPage: page,
          requestedPageSize: pageSize,
        );
      } catch (_) {
        final response = await _supabase.rpc('get_points_history');
        return PaginatedResponse.fromRpc(
          response: response,
          fromJson: (json) => json,
          requestedPage: page,
          requestedPageSize: pageSize,
        );
      }
    } catch (e) {
      return PaginatedResponse(
        items: const [],
        totalCount: 0,
        page: page,
        pageSize: pageSize,
      );
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
  Future<UserModel> updateProfile(UpdateProfileParams params) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw const UserNotFoundException();
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

      final updateData = {
        'full_name': params.name,
        'phone': params.phone,
        if (params.email != null) 'email': params.email,
        'avatar_url': avatarUrl,
      };

      await _supabase.from('profiles').update(updateData).eq('id', userId);

      await _supabase.auth.updateUser(
        UserAttributes(
          email: params.email,
          data: {
            'full_name': params.name,
            'avatar_url': avatarUrl,
          },
        ),
      );

      debugPrint(' [Profile] Profile updated');

      return UserModel.fromSupabaseUser(_supabase.auth.currentUser!.toJson())
          .copyWith(
        name: params.name,
        phone: params.phone,
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

  @override
  Future<UserModel> getUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw const UserNotFoundException();

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      var userModel = UserModel.fromJson(Map<String, dynamic>.from(data));
      if (userModel.referralCode == null || userModel.referralCode!.trim().isEmpty) {
        final fallbackCode = 'PLAY-${user.id.substring(0, 6).toUpperCase()}';
        try {
          await _supabase.from('profiles').update({'referral_code': fallbackCode}).eq('id', user.id);
          userModel = userModel.copyWith(referralCode: fallbackCode);
        } catch (_) {}
      }
      return userModel;
    } catch (e) {
      final userModel = UserModel.fromSupabaseUser(user.toJson());
      if (userModel.referralCode == null || userModel.referralCode!.trim().isEmpty) {
        return userModel.copyWith(
          referralCode: 'PLAY-${user.id.substring(0, 6).toUpperCase()}',
        );
      }
      return userModel;
    }
  }

  @override
  Future<void> updateFcmToken(String token) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase.from('profiles').update({'fcm_token': token}).eq('id', user.id);
      debugPrint(' [Profile] FCM token updated for user: ${user.id}');
    } catch (e) {
      debugPrint(' [Profile] Update FCM token error: $e');
    }
  }

  @override
  Future<NotificationSettingsModel> getNotificationSettings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const NotificationSettingsModel();

    try {
      final response = await _supabase
          .from('notification_settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        return NotificationSettingsModel.fromJson(Map<String, dynamic>.from(response));
      }
    } catch (e) {
      debugPrint(' [Profile] Error getting notification settings: $e');
    }
    return const NotificationSettingsModel();
  }

  @override
  Future<void> updateNotificationSettings(NotificationSettingsModel settings) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final data = {
      'user_id': user.id,
      ...settings.toJson(),
    };

    try {
      await _supabase.from('notification_settings').upsert(data, onConflict: 'user_id');
    } catch (e) {
      debugPrint(' [Profile] Error updating notification settings: $e');
    }
  }

  @override
  Future<LoyaltyStatusModel> getLoyaltyStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const LoyaltyStatusModel(
        pointsBalance: 0,
        currentLevel: 'Bronze',
        nextLevelPoints: 100,
        multiplier: 1.0,
      );
    }

    try {
      final response = await _supabase.rpc('get_loyalty_status', params: {
        'p_user_id': user.id,
      });

      if (response != null) {
        if (response is Map) {
          return LoyaltyStatusModel.fromJson(Map<String, dynamic>.from(response));
        } else if (response is List && response.isNotEmpty && response.first is Map) {
          return LoyaltyStatusModel.fromJson(Map<String, dynamic>.from(response.first));
        }
      }
    } catch (e) {
      debugPrint('[Profile] get_loyalty_status RPC error: $e');
    }

    final points = await getPointsBalance();
    return LoyaltyStatusModel(
      pointsBalance: points,
      currentLevel: points >= 1000 ? 'Gold' : (points >= 500 ? 'Silver' : 'Bronze'),
      nextLevelPoints: points >= 1000 ? 2000 : (points >= 500 ? 1000 : 500),
      multiplier: points >= 1000 ? 1.5 : (points >= 500 ? 1.2 : 1.0),
    );
  }

  @override
  Future<List<LoyaltyMissionModel>> getLoyaltyMissions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final missionsRes = await _supabase
          .from('loyalty_missions')
          .select()
          .eq('is_active', true);

      final progressRes = await _supabase
          .from('user_mission_progress')
          .select()
          .eq('user_id', user.id);

      final progressMap = <String, Map<String, dynamic>>{};
      for (final p in (progressRes as List)) {
        if (p is Map) {
          final mId = p['mission_id']?.toString() ?? '';
          if (mId.isNotEmpty) {
            progressMap[mId] = Map<String, dynamic>.from(p);
          }
        }
      }

      return (missionsRes as List).map((m) {
        final mMap = Map<String, dynamic>.from(m as Map);
        final mId = mMap['id']?.toString() ?? '';
        return LoyaltyMissionModel.fromJson(mMap, progressJson: progressMap[mId]);
      }).toList();
    } catch (e) {
      debugPrint('[Profile] Error fetching loyalty missions: $e');
    }
    return [];
  }

  @override
  Future<UserReferralStatsModel> getReferralStats() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const UserReferralStatsModel(
        referralCode: '',
        invitedUsersCount: 0,
        referralPointsEarned: 0,
      );
    }

    String refCode = '';
    try {
      final profile = await _supabase
          .from('profiles')
          .select('referral_code')
          .eq('id', user.id)
          .maybeSingle();
      refCode = profile?['referral_code']?.toString() ??
          'PLAY-${user.id.substring(0, 6).toUpperCase()}';
    } catch (_) {
      refCode = 'PLAY-${user.id.substring(0, 6).toUpperCase()}';
    }

    int count = 0;
    int points = 0;

    try {
      final referralsRes = await _supabase
          .from('referrals')
          .select('*')
          .eq('referrer_id', user.id);

      final list = referralsRes as List;
      count = list.length;
      for (final item in list) {
        if (item is Map) {
          points += ((item['reward_points'] ??
                  item['points'] ??
                  item['points_awarded']) as num?)
              ?.toInt() ?? 0;
        }
      }
    } catch (e) {
      debugPrint('[Profile] Error fetching referrals: $e');
    }

    if (points == 0) {
      try {
        final txRes = await _supabase
            .from('points_transactions')
            .select('points')
            .eq('user_id', user.id)
            .or('source_type.eq.referral,source_type.eq.referral_bonus,description.ilike.%referral%');
        for (final tx in (txRes as List)) {
          if (tx is Map) {
            points += ((tx['points']) as num?)?.toInt() ?? 0;
          }
        }
      } catch (_) {}
    }

    return UserReferralStatsModel(
      referralCode: refCode,
      invitedUsersCount: count,
      referralPointsEarned: points,
    );
  }

  @override
  Future<ClaimReferralResult> claimReferralCode(String referralCode) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const ClaimReferralResult(
        status: ClaimReferralStatus.error,
        messageKey: AppStrings.userNotLoggedIn,
      );
    }

    final cleanCode = referralCode.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return const ClaimReferralResult(
        status: ClaimReferralStatus.invalidCode,
        messageKey: AppStrings.invalidReferralCode,
      );
    }

    try {
      final response = await _supabase.rpc('claim_referral_code', params: {
        'p_referral_code': cleanCode,
      });

      if (response != null) {
        if (response is Map) {
          final map = Map<String, dynamic>.from(response);
          if (map['success'] == true) {
            return const ClaimReferralResult(
              status: ClaimReferralStatus.success,
              messageKey: AppStrings.referralActivatedSuccess,
            );
          } else if (map['already_claimed'] == true ||
              map['status'] == 'already_claimed' ||
              (map['message']?.toString().contains('already') ?? false)) {
            return const ClaimReferralResult(
              status: ClaimReferralStatus.alreadyClaimed,
              messageKey: AppStrings.referralAlreadyClaimed,
            );
          } else if (map['error'] != null) {
            final err = map['error'].toString();
            if (err.contains('أكد الإيميل') || err.contains('confirm email') || err.contains('unconfirmed')) {
              return const ClaimReferralResult(
                status: ClaimReferralStatus.emailUnconfirmed,
                messageKey: AppStrings.confirmEmailFirst,
              );
            } else if (err.contains('غير صحيح') || err.contains('invalid') || err.contains('not found')) {
              return const ClaimReferralResult(
                status: ClaimReferralStatus.invalidCode,
                messageKey: AppStrings.invalidReferralCode,
              );
            }
            return const ClaimReferralResult(
              status: ClaimReferralStatus.error,
              messageKey: AppStrings.somethingWentWrong,
            );
          }
        } else if (response == true) {
          return const ClaimReferralResult(
            status: ClaimReferralStatus.success,
            messageKey: AppStrings.referralActivatedSuccess,
          );
        }
      }

      return const ClaimReferralResult(
        status: ClaimReferralStatus.success,
        messageKey: AppStrings.referralActivatedSuccess,
      );
    } on PostgrestException catch (e) {
      final msg = e.message;
      debugPrint('[Profile] claim_referral_code PostgrestException: $msg');
      if (msg.contains('أكد الإيميل') || msg.contains('confirm email') || msg.contains('unconfirmed')) {
        return const ClaimReferralResult(
          status: ClaimReferralStatus.emailUnconfirmed,
          messageKey: AppStrings.confirmEmailFirst,
        );
      } else if (msg.contains('غير صحيح') || msg.contains('invalid') || msg.contains('not found')) {
        return const ClaimReferralResult(
          status: ClaimReferralStatus.invalidCode,
          messageKey: AppStrings.invalidReferralCode,
        );
      } else if (msg.contains('already') || msg.contains('سبق استخدام')) {
        return const ClaimReferralResult(
          status: ClaimReferralStatus.alreadyClaimed,
          messageKey: AppStrings.referralAlreadyClaimed,
        );
      }
      return const ClaimReferralResult(
        status: ClaimReferralStatus.error,
        messageKey: AppStrings.somethingWentWrong,
      );
    } catch (e) {
      final msg = e.toString();
      debugPrint('[Profile] claim_referral_code error: $msg');
      if (msg.contains('أكد الإيميل') || msg.contains('confirm email')) {
        return const ClaimReferralResult(
          status: ClaimReferralStatus.emailUnconfirmed,
          messageKey: AppStrings.confirmEmailFirst,
        );
      } else if (msg.contains('غير صحيح') || msg.contains('invalid')) {
        return const ClaimReferralResult(
          status: ClaimReferralStatus.invalidCode,
          messageKey: AppStrings.invalidReferralCode,
        );
      }
      return const ClaimReferralResult(
        status: ClaimReferralStatus.error,
        messageKey: AppStrings.somethingWentWrong,
      );
    }
  }

  @override
  Future<int> getTotalBookingsCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;
      final res = await _supabase
          .from('bookings')
          .select('id')
          .eq('user_id', user.id);
      return (res as List).length;
    } catch (e) {
      debugPrint('[Profile] Error fetching total bookings count: $e');
      return 0;
    }
  }
}
