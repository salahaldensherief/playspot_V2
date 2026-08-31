import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../datasources/local/auth_local_data_source.dart';
import '../datasources/remote/auth_remote_data_source.dart';
import '../models/auth_params.dart';
import '../models/user_model.dart';
import '../../domain/repositories/auth_repo.dart';

class AuthRepositoryImpl with RepositoryHelper implements AuthRepository {
  final AuthRemoteSource _remoteSource;
  final AuthLocalDataSource _localDataSource;

  AuthRepositoryImpl(this._remoteSource, this._localDataSource);

  @override
  Future<Either<Failure, UserModel>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await callRepository(() async {
      final user = await _remoteSource.signInWithEmail(email: email, password: password);
      await _localDataSource.saveUserData(user);
      return user;
    });
  }

  @override
  Future<Either<Failure, UserModel>> signUpWithEmail(SignUpParams params) async {
    return await callRepository(() async {
      final user = await _remoteSource.signUpWithEmail(params);
      await _localDataSource.saveUserData(user);
      return user;
    });
  }

  @override
  Future<Either<Failure, UserModel>> signInWithGoogle() async {
    return await callRepository(() async {
      final user = await _remoteSource.signInWithGoogle();
      await _localDataSource.saveUserData(user);
      return user;
    });
  }

  @override
  Future<Either<Failure, UserModel>> signInWithFacebook() async {
    return await callRepository(() async {
      final user = await _remoteSource.signInWithFacebook();
      await _localDataSource.saveUserData(user);
      return user;
    });
  }

  @override
  Future<Either<Failure, UserModel>> completeProfile(CompleteProfileParams params) async {
    return await callRepository(() async {
      final user = await _remoteSource.completeProfile(params);
      await _localDataSource.saveUserData(user);
      return user;
    });
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    return await callRepository(() async {
      await _remoteSource.signOut();
      await _localDataSource.clearUserData();
    });
  }

  @override
  UserModel? getCurrentUser() {
    final cachedUser = _localDataSource.getCachedUser();
    if (cachedUser != null) return cachedUser;

    final user = _remoteSource.getCurrentUser();
    if (user != null) _localDataSource.saveUserData(user);
    return user;
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    return await callRepository(() => _remoteSource.sendPasswordResetEmail(email));
  }

  @override
  Future<Either<Failure, void>> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    return await callRepository(() => _remoteSource.verifyPasswordResetOTP(email: email, otp: otp));
  }

  @override
  Future<Either<Failure, void>> resetPassword(String newPassword) async {
    return await callRepository(() => _remoteSource.resetPassword(newPassword));
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    return await callRepository(() => _remoteSource.deleteAccount());
  }
}
