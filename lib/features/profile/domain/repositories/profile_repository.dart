import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/models/paginated_response.dart';
import 'package:playspot/features/auth/data/models/user_model.dart';
import 'package:playspot/features/profile/data/models/notification_settings_model.dart';
import 'package:playspot/features/profile/data/models/redemption_option_model.dart';
import 'package:playspot/features/profile/data/models/profile_params.dart';
import 'package:playspot/features/profile/data/models/loyalty_status_model.dart';
import 'package:playspot/features/profile/data/models/loyalty_mission_model.dart';
import 'package:playspot/features/profile/data/models/user_referral_stats_model.dart';
import 'package:playspot/features/profile/data/models/claim_referral_result.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserModel>> updateProfile(UpdateProfileParams params);
  UserModel? getCurrentUser();
  Future<Either<Failure, UserModel>> getUserProfile();
  Future<Either<Failure, int>> getPointsBalance();
  Future<Either<Failure, PaginatedResponse<Map<String, dynamic>>>> getPointsHistory({
    int page = 1,
    int pageSize = 20,
  });
  Future<Either<Failure, List<RedemptionOptionModel>>> getRedemptionOptions();
  Future<Either<Failure, Map<String, dynamic>>> redeemPoints(String optionId);
  Future<Either<Failure, List<Map<String, dynamic>>>> getMyVouchers();
  Future<Either<Failure, Map<String, dynamic>>> validateVoucher(String voucherId);
  Future<Either<Failure, Map<String, dynamic>>> validateVoucherByCode(String code);
  Future<Either<Failure, void>> consumeVoucher({required String voucherId, required String bookingId});
  Future<void> updateFcmToken(String token);
  Future<Either<Failure, NotificationSettingsModel>> getNotificationSettings();
  Future<Either<Failure, void>> updateNotificationSettings(NotificationSettingsModel settings);
  Future<Either<Failure, LoyaltyStatusModel>> getLoyaltyStatus();
  Future<Either<Failure, List<LoyaltyMissionModel>>> getLoyaltyMissions();
  Future<Either<Failure, UserReferralStatsModel>> getReferralStats();
  Future<Either<Failure, ClaimReferralResult>> claimReferralCode(String referralCode);
  Future<Either<Failure, int>> getTotalBookingsCount();
}
