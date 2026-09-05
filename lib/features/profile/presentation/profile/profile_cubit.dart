import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/profile/data/models/redemption_option_model.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  ProfileCubit(this._authRepository, this._profileRepository) : super(ProfileState());

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
      ]);

      final pointsRes = results[0] as Either<Failure, int>;
      final optionsRes = results[1] as Either<Failure, List<RedemptionOptionModel>>;
      final vouchersRes = results[2] as Either<Failure, List<Map<String, dynamic>>>;

      emit(state.copyWith(
        status: ProfileStatus.success,
        user: user,
        pointsBalance: pointsRes.fold((l) => 0, (r) => r),
        redemptionOptions: optionsRes.fold((l) => [], (r) => r),
        myVouchers: vouchersRes.fold((l) => [], (r) => r),
      ));
    } else {
      emit(state.copyWith(status: ProfileStatus.error, errorMessage: "User not found"));
    }
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
          getUserData(); // Refresh all data
        } else {
          final errorMsg = data['error']?.toString() ?? "Failed to redeem points";
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
