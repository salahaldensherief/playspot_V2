import 'package:equatable/equatable.dart';
import 'package:playspot/features/auth/data/models/user_model.dart';
import 'package:playspot/features/profile/data/models/redemption_option_model.dart';
import 'package:playspot/features/profile/data/models/loyalty_status_model.dart';
import 'package:playspot/features/profile/data/models/loyalty_mission_model.dart';
import 'package:playspot/features/profile/data/models/user_referral_stats_model.dart';
import 'package:playspot/features/profile/data/models/claim_referral_result.dart';

enum ProfileStatus {
  initial,
  loading,
  success,
  error,
  logoutSuccess,
  redeemSuccess,
  claimReferralResult,
}

class ProfileState extends Equatable {
  final ProfileStatus status;
  final UserModel? user;
  final int pointsBalance;
  final int totalBookingsCount;
  final List<RedemptionOptionModel> redemptionOptions;
  final List<Map<String, dynamic>> myVouchers;
  final List<Map<String, dynamic>> pointsHistory;
  final int pointsPage;
  final bool hasMorePointsHistory;
  final bool isLoadingMorePointsHistory;
  final int pointsTotalCount;
  final LoyaltyStatusModel? loyaltyStatus;
  final List<LoyaltyMissionModel> loyaltyMissions;
  final UserReferralStatsModel? referralStats;
  final ClaimReferralResult? claimResult;
  final String? errorMessage;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.pointsBalance = 0,
    this.totalBookingsCount = 0,
    this.redemptionOptions = const [],
    this.myVouchers = const [],
    this.pointsHistory = const [],
    this.pointsPage = 1,
    this.hasMorePointsHistory = true,
    this.isLoadingMorePointsHistory = false,
    this.pointsTotalCount = 0,
    this.loyaltyStatus,
    this.loyaltyMissions = const [],
    this.referralStats,
    this.claimResult,
    this.errorMessage,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    UserModel? user,
    int? pointsBalance,
    int? totalBookingsCount,
    List<RedemptionOptionModel>? redemptionOptions,
    List<Map<String, dynamic>>? myVouchers,
    List<Map<String, dynamic>>? pointsHistory,
    int? pointsPage,
    bool? hasMorePointsHistory,
    bool? isLoadingMorePointsHistory,
    int? pointsTotalCount,
    LoyaltyStatusModel? loyaltyStatus,
    List<LoyaltyMissionModel>? loyaltyMissions,
    UserReferralStatsModel? referralStats,
    ClaimReferralResult? claimResult,
    String? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      totalBookingsCount: totalBookingsCount ?? this.totalBookingsCount,
      redemptionOptions: redemptionOptions ?? this.redemptionOptions,
      myVouchers: myVouchers ?? this.myVouchers,
      pointsHistory: pointsHistory ?? this.pointsHistory,
      pointsPage: pointsPage ?? this.pointsPage,
      hasMorePointsHistory: hasMorePointsHistory ?? this.hasMorePointsHistory,
      isLoadingMorePointsHistory: isLoadingMorePointsHistory ?? this.isLoadingMorePointsHistory,
      pointsTotalCount: pointsTotalCount ?? this.pointsTotalCount,
      loyaltyStatus: loyaltyStatus ?? this.loyaltyStatus,
      loyaltyMissions: loyaltyMissions ?? this.loyaltyMissions,
      referralStats: referralStats ?? this.referralStats,
      claimResult: claimResult ?? this.claimResult,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        user,
        pointsBalance,
        totalBookingsCount,
        redemptionOptions,
        myVouchers,
        pointsHistory,
        pointsPage,
        hasMorePointsHistory,
        isLoadingMorePointsHistory,
        pointsTotalCount,
        loyaltyStatus,
        loyaltyMissions,
        referralStats,
        claimResult,
        errorMessage,
      ];
}
