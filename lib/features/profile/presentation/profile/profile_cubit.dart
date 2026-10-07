import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/models/paginated_response.dart';
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/profile/data/models/claim_referral_result.dart';
import 'package:playspot/features/profile/data/models/loyalty_mission_model.dart';
import 'package:playspot/features/profile/data/models/loyalty_status_model.dart';
import 'package:playspot/features/profile/data/models/redemption_option_model.dart';
import 'package:playspot/features/profile/data/models/user_referral_stats_model.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:playspot/features/auth/data/models/user_model.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final PreferenceManager _preferenceManager;
  int _pointsHistoryGeneration = 0;

  ProfileCubit(
    this._authRepository,
    this._profileRepository,
    this._preferenceManager,
  ) : super(const ProfileState());

  void updateUser(UserModel updatedUser) {
    if (!isClosed) {
      emit(state.copyWith(user: updatedUser));
    }
  }

  Future<void> loadPointsHistory({bool refresh = false}) async {
    if (isClosed || (!refresh &&
        (state.isLoadingMorePointsHistory || !state.hasMorePointsHistory))) return;
    final generation = ++_pointsHistoryGeneration;
    final page = refresh || state.pointsHistory.isEmpty ? 1 : state.pointsPage + 1;
    emit(state.copyWith(isLoadingMorePointsHistory: true, pointsHistoryFailed: false));
    final result = await _profileRepository.getPointsHistory(page: page);
    if (isClosed || generation != _pointsHistoryGeneration) return;
    result.fold<void>((_) {
      emit(state.copyWith(isLoadingMorePointsHistory: false, pointsHistoryFailed: true));
    }, (response) {
      final items = <Map<String, dynamic>>[
        if (!refresh) ...state.pointsHistory,
        ...response.items,
      ];
      final seen = <String>{};
      final unique = items.where((item) {
        final id = item['id']?.toString();
        return id == null || seen.add(id);
      }).toList();
      emit(state.copyWith(pointsHistory: unique, pointsPage: response.page,
        pointsTotalCount: response.totalCount, hasMorePointsHistory: response.hasMore,
        isLoadingMorePointsHistory: false, pointsHistoryFailed: false));
    });
  }

  void getUserData() async {
    if (isClosed) return;

    // Cache-First Strategy: Instantly render cached user data for 0ms loading
    final cachedUser = _profileRepository.getCurrentUser();
    if (cachedUser != null && state.user == null) {
      emit(state.copyWith(
        status: ProfileStatus.success,
        user: cachedUser,
      ));
    } else if (state.user == null) {
      emit(state.copyWith(status: ProfileStatus.loading));
    }

    final userProfileRes = await _profileRepository.getUserProfile();
    if (isClosed) return;

    final user = userProfileRes.fold(
      (_) => cachedUser ?? _profileRepository.getCurrentUser(),
      (userModel) => userModel,
    );

    if (user != null) {
      try {
        final historyGeneration = _pointsHistoryGeneration;
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

        if (isClosed) return;

        final pointsRes = results[0] as Either<Failure, int>;
        final optionsRes =
            results[1] as Either<Failure, List<RedemptionOptionModel>>;
        final vouchersRes =
            results[2] as Either<Failure, List<Map<String, dynamic>>>;
        final historyRes =
            results[3]
                as Either<Failure, PaginatedResponse<Map<String, dynamic>>>;
        final loyaltyRes = results[4] as Either<Failure, LoyaltyStatusModel>;
        final missionsRes =
            results[5] as Either<Failure, List<LoyaltyMissionModel>>;
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

        if (!isClosed) {
          emit(
            state.copyWith(
              status: ProfileStatus.success,
              user: user,
              pointsBalance: points,
              totalBookingsCount: totalBookings,
              redemptionOptions: optionsRes.fold((l) => [], (r) => r),
              myVouchers: vouchersRes.fold((l) => [], (r) => r),
              pointsHistory: historyGeneration == _pointsHistoryGeneration
                  ? historyRes.fold((l) => state.pointsHistory, (r) => r.items)
                  : state.pointsHistory,
              pointsPage: historyGeneration == _pointsHistoryGeneration
                  ? historyRes.fold((l) => state.pointsPage, (r) => r.page) : state.pointsPage,
              pointsTotalCount: historyGeneration == _pointsHistoryGeneration
                  ? historyRes.fold((l) => state.pointsTotalCount, (r) => r.totalCount) : state.pointsTotalCount,
              hasMorePointsHistory: historyGeneration == _pointsHistoryGeneration
                  ? historyRes.fold((l) => true, (r) => r.hasMore) : state.hasMorePointsHistory,
              pointsHistoryFailed: historyGeneration == _pointsHistoryGeneration
                  ? historyRes.isLeft() : state.pointsHistoryFailed,
              loyaltyStatus: loyaltyStatus,
              loyaltyMissions: missionsRes.fold((l) => [], (r) => r),
              referralStats: statsRes.fold((l) => null, (r) => r),
            ),
          );
        }

        // Check if there is a pending referral code to claim after successful auth & email confirmation
        claimPendingReferralCode();
      } catch (e) {
        if (!isClosed) {
          emit(
            state.copyWith(
              status: ProfileStatus.error,
              errorMessage: e.toString(),
            ),
          );
        }
      }
    } else {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ProfileStatus.error,
            errorMessage: AppStrings.userNotFound,
          ),
        );
      }
    }
  }

  Future<void> claimPendingReferralCode() async {
    final pendingCode = _preferenceManager.getPendingReferralCode();
    if (pendingCode.isEmpty) return;

    final user = _authRepository.getCurrentUser();
    if (user == null) return;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) return;

    final isOAuth =
        supabaseUser.appMetadata['provider'] != 'email' &&
        supabaseUser.appMetadata['provider'] != null;
    final isEmailConfirmed =
        supabaseUser.emailConfirmedAt != null ||
        isOAuth ||
        (supabaseUser.email == null || supabaseUser.email!.isEmpty);

    if (!isEmailConfirmed) {
      // Do not call claim_referral_code before email confirmation!
      return;
    }

    final result = await _profileRepository.claimReferralCode(pendingCode);
    result.fold((failure) {}, (claimRes) {
      if (claimRes.status == ClaimReferralStatus.success ||
          claimRes.status == ClaimReferralStatus.alreadyClaimed ||
          claimRes.status == ClaimReferralStatus.invalidCode) {
        _preferenceManager.clearPendingReferralCode();
      }

      if (!isClosed) {
        emit(
          state.copyWith(
            status: ProfileStatus.claimReferralResult,
            claimResult: claimRes,
          ),
        );
      }

      if (claimRes.status == ClaimReferralStatus.success) {
        getUserData();
      }
    });
  }

  Future<void> redeemPoints(String optionId) async {
    if (isClosed || state.status == ProfileStatus.loading) return;
    emit(state.copyWith(status: ProfileStatus.loading));
    final result = await _profileRepository.redeemPoints(optionId);

    result.fold(
      (failure) {
        if (!isClosed) {
          emit(
            state.copyWith(
              status: ProfileStatus.error,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (data) async {
        if (data['success'] == true) {
          final newBalance =
              (data['new_balance'] as num?)?.toInt() ?? state.pointsBalance;
          if (!isClosed) {
            emit(
              state.copyWith(
                status: ProfileStatus.redeemSuccess,
                pointsBalance: newBalance,
              ),
            );
          }
          await Future.delayed(const Duration(milliseconds: 200));
          if (!isClosed) {
            getUserData();
          }
        } else {
          final errorMsg =
              data['error']?.toString() ?? AppStrings.failedToRedeemPoints;
          if (!isClosed) {
            emit(
              state.copyWith(
                status: ProfileStatus.error,
                errorMessage: errorMsg,
              ),
            );
          }
        }
      },
    );
  }

  Future<void> logout() async {
    if (isClosed || state.status == ProfileStatus.loggingOut) return;
    emit(state.copyWith(status: ProfileStatus.loggingOut));
    final result = await _authRepository.signOut();

    result.fold(
      (failure) {
        if (!isClosed) {
          emit(
            state.copyWith(
              status: ProfileStatus.error,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (_) {
        if (!isClosed) {
          emit(state.copyWith(status: ProfileStatus.logoutSuccess));
        }
      },
    );
  }
}
