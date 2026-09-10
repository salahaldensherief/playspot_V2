import 'package:equatable/equatable.dart';
import 'package:playspot/features/auth/data/models/user_model.dart';
import 'package:playspot/features/profile/data/models/redemption_option_model.dart';

enum ProfileStatus { initial, loading, success, error, logoutSuccess, redeemSuccess }

class ProfileState extends Equatable {
  final ProfileStatus status;
  final UserModel? user;
  final int pointsBalance;
  final List<RedemptionOptionModel> redemptionOptions;
  final List<Map<String, dynamic>> myVouchers;
  final List<Map<String, dynamic>> pointsHistory;
  final String? errorMessage;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.pointsBalance = 0,
    this.redemptionOptions = const [],
    this.myVouchers = const [],
    this.pointsHistory = const [],
    this.errorMessage,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    UserModel? user,
    int? pointsBalance,
    List<RedemptionOptionModel>? redemptionOptions,
    List<Map<String, dynamic>>? myVouchers,
    List<Map<String, dynamic>>? pointsHistory,
    String? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      redemptionOptions: redemptionOptions ?? this.redemptionOptions,
      myVouchers: myVouchers ?? this.myVouchers,
      pointsHistory: pointsHistory ?? this.pointsHistory,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, pointsBalance, redemptionOptions, myVouchers, pointsHistory, errorMessage];
}
