import 'package:equatable/equatable.dart';

class UserReferralStatsModel extends Equatable {
  final String referralCode;
  final int invitedUsersCount;
  final int referralPointsEarned;

  const UserReferralStatsModel({
    required this.referralCode,
    required this.invitedUsersCount,
    required this.referralPointsEarned,
  });

  factory UserReferralStatsModel.fromJson(Map<String, dynamic> json) {
    return UserReferralStatsModel(
      referralCode: json['referral_code']?.toString() ?? '',
      invitedUsersCount: ((json['invited_count'] ?? json['invited_users_count'] ?? json['total_referrals']) as num?)?.toInt() ?? 0,
      referralPointsEarned: ((json['referral_points'] ?? json['points_earned'] ?? json['total_points_earned']) as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'referral_code': referralCode,
    'invited_count': invitedUsersCount,
    'referral_points': referralPointsEarned,
  };

  @override
  List<Object?> get props => [referralCode, invitedUsersCount, referralPointsEarned];
}
