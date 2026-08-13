import '../../auth/data/models/user_model.dart';

import '../data/models/redemption_option_model.dart';

enum ProfileStatus { initial, loading, success, error, logoutSuccess, redeemSuccess }

class ProfileState {
  final ProfileStatus status;
  final UserModel? user;
  final int pointsBalance;
  final List<RedemptionOptionModel> redemptionOptions;
  final List<Map<String, dynamic>> myVouchers;
  final String? errorMessage;

  ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.pointsBalance = 0,
    this.redemptionOptions = const [],
    this.myVouchers = const [],
    this.errorMessage,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    UserModel? user,
    int? pointsBalance,
    List<RedemptionOptionModel>? redemptionOptions,
    List<Map<String, dynamic>>? myVouchers,
    String? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      redemptionOptions: redemptionOptions ?? this.redemptionOptions,
      myVouchers: myVouchers ?? this.myVouchers,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
