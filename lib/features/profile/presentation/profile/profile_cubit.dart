import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/profile/data/models/redemption_option_model.dart';
import 'package:playspot/features/profile/data/models/loyalty_status_model.dart';
import 'package:playspot/features/profile/data/models/loyalty_mission_model.dart';
import 'package:playspot/features/profile/data/models/user_referral_stats_model.dart';
import 'package:playspot/features/profile/data/models/claim_referral_result.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final PreferenceManager _preferenceManager;

  ProfileCubit(
    this._authRepository,
    this._profileRepository,
    this._preferenceManager,
  ) : super(const ProfileState());

  void getUserData() async {
    emit(state.copyWith(status: ProfileStatus.loading));

    final userProfileRes = await _profileRepository.getUserProfile();
    final user = userProfileRes.fold(
      (_) => _profileRepository.getCurrentUser(),
      (userModel) => userModel,
    );

    if (user != null) {
      final results = await Future.wait([
        _profileRepository.getPointsBalance(),
        _profileRepository.getRedemptionOptions(),
        _profileRepository.getMyVouchers(),
        _profileRepository.getPointsHistory(),
        _profileRepository.getLoyaltyStatus(),
        _profileRepository.getLoyaltyMissions(),
        _profileRepository.getReferralStats(),
        _profileRepository.getTotalBookingsCount(),
      ]);

      final pointsRes = results[0] as Either<Failure, int>;
      final optionsRes = results[1] as Either<Failure, List<RedemptionOptionModel>>;
      final vouchersRes = results[2] as Either<Failure, List<Map<String, dynamic>>>;
      final historyRes = results[3] as Either<Failure, List<Map<String, dynamic>>>;
      final loyaltyRes = results[4] as Either<Failure, LoyaltyStatusModel>;
      final missionsRes = results[5] as Either<Failure, List<LoyaltyMissionModel>>;
      final statsRes = results[6] as Either<Failure, UserReferralStatsModel>;
      final bookingsCountRes = results[7] as Either<Failure, int>;

      final points = pointsRes.fold((l) => 0, (r) => r);
      final totalBookings = bookingsCountRes.fold((l) => 0, (r) => r);
      final loyaltyStatus = loyaltyRes.fold(
        (l) => LoyaltyStatusModel(
          pointsBalance: points,
          currentLevel: 'Bronze',
          nextLevelPoints: 100,
          multiplier: 1.0,
        ),
        (r) => r,
      );

      emit(state.copyWith(
        status: ProfileStatus.success,
        user: user,
        pointsBalance: points,
        totalBookingsCount: totalBookings,
        redemptionOptions: optionsRes.fold((l) => [], (r) => r),
        myVouchers: vouchersRes.fold((l) => [], (r) => r),
        pointsHistory: historyRes.fold((l) => [], (r) => r),
        loyaltyStatus: loyaltyStatus,
        loyaltyMissions: missionsRes.fold((l) => [], (r) => r),
        referralStats: statsRes.fold((l) => null, (r) => r),
      ));

      // Check if there is a pending referral code to claim after successful auth & email confirmation
      claimPendingReferralCode();
    } else {
      emit(state.copyWith(status: ProfileStatus.error, errorMessage: AppStrings.userNotFound));
    }
  }

  Future<void> claimPendingReferralCode() async {
    final pendingCode = _preferenceManager.getPendingReferralCode();
    if (pendingCode.isEmpty) return;

    final user = _authRepository.getCurrentUser();
    if (user == null) return;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) return;

    final isOAuth = supabaseUser.appMetadata['provider'] != 'email' &&
        supabaseUser.appMetadata['provider'] != null;
    final isEmailConfirmed = supabaseUser.emailConfirmedAt != null ||
        isOAuth ||
        (supabaseUser.email == null || supabaseUser.email!.isEmpty);

    if (!isEmailConfirmed) {
      // Do not call claim_referral_code before email confirmation!
      return;
    }

    final result = await _profileRepository.claimReferralCode(pendingCode);
    result.fold(
      (failure) {},
      (claimRes) {
        if (claimRes.status == ClaimReferralStatus.success ||
            claimRes.status == ClaimReferralStatus.alreadyClaimed ||
            claimRes.status == ClaimReferralStatus.invalidCode) {
          _preferenceManager.clearPendingReferralCode();
        }

        emit(state.copyWith(
          status: ProfileStatus.claimReferralResult,
          claimResult: claimRes,
        ));

        if (claimRes.status == ClaimReferralStatus.success) {
          getUserData();
        }
      },
    );
  }

  Future<void> redeemPoints(String optionId) async {
    emit(state.copyWith(status: ProfileStatus.loading));
    final result = await _profileRepository.redeemPoints(optionId);

    result.fold(
      (failure) => emit(state.copyWith(status: ProfileStatus.error, errorMessage: failure.message)),
      (data) {
        if (data['success'] == true) {
          final newBalance = (data['new_balance'] as num?)?.toInt() ?? state.pointsBalance;
          emit(state.copyWith(
            status: ProfileStatus.redeemSuccess,
            pointsBalance: newBalance,
          ));
          getUserData();
        } else {
          final errorMsg = data['error']?.toString() ?? AppStrings.failedToRedeemPoints;
          emit(state.copyWith(status: ProfileStatus.error, errorMessage: errorMsg));
        }
      },
    );
  }

  Future<void> logout() async {
    emit(state.copyWith(status: ProfileStatus.loading));
    final result = await _authRepository.signOut();

    result.fold(
      (failure) => emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(status: ProfileStatus.logoutSuccess)),
    );
  }
}
