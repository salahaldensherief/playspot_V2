import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/cache/preference_manager.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/redemption_option_model.dart';
import '../models/profile_params.dart';
import '../data_source/remote/profile_remote_data_source.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserModel>> updateProfile(UpdateProfileParams params);
  UserModel? getCurrentUser();
  Future<Either<Failure, int>> getPointsBalance();
  Future<Either<Failure, List<RedemptionOptionModel>>> getRedemptionOptions();
  Future<Either<Failure, Map<String, dynamic>>> redeemPoints(String optionId);
  Future<Either<Failure, List<Map<String, dynamic>>>> getMyVouchers();
  Future<Either<Failure, Map<String, dynamic>>> validateVoucher(String voucherId);
  Future<Either<Failure, void>> consumeVoucher({required String voucherId, required String bookingId});
}

class ProfileRepositoryImpl with RepositoryHelper implements ProfileRepository {
  final ProfileRemoteDataSource _remoteSource;
  final PreferenceManager _preferenceManager;

  ProfileRepositoryImpl(this._remoteSource, this._preferenceManager);

  @override
  Future<Either<Failure, void>> consumeVoucher({required String voucherId, required String bookingId}) async {
    return await callRepository(() => _remoteSource.consumeVoucher(voucherId: voucherId, bookingId: bookingId));
  }

  @override
  Future<Either<Failure, int>> getPointsBalance() async {
    return await callRepository(() => _remoteSource.getPointsBalance());
  }

  @override
  Future<Either<Failure, List<RedemptionOptionModel>>> getRedemptionOptions() async {
    return await callRepository(() => _remoteSource.getRedemptionOptions());
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> redeemPoints(String optionId) async {
    return await callRepository(() => _remoteSource.redeemPoints(optionId));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getMyVouchers() async {
    return await callRepository(() => _remoteSource.getMyVouchers());
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> validateVoucher(String voucherId) async {
    return await callRepository(() => _remoteSource.validateVoucher(voucherId));
  }

  void _saveUserData(UserModel user) {
    _preferenceManager.saveUserId(user.id);
    _preferenceManager.saveFullName(user.name);
    _preferenceManager.saveUserData(user);
  }

  @override
  Future<Either<Failure, UserModel>> updateProfile(UpdateProfileParams params) async {
    return await callRepository(() async {
      final user = await _remoteSource.updateProfile(params);
      _saveUserData(user);
      return user;
    });
  }

  @override
  UserModel? getCurrentUser() {
    final cachedUser = _preferenceManager.getUserData();
    if (cachedUser != null) {
      return cachedUser;
    }

    final user = _remoteSource.getCurrentUser();
    if (user != null) {
      _saveUserData(user);
    }
    return user;
  }
}
