import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../data/models/user_model.dart';
import '../data_source/remote/auth_remote_data_source.dart';
import '../data_source/local/auth_local_data_source.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserModel>> signInWithEmail({
    required String email,
    required String password,
  });
  Future<Either<Failure, UserModel>> signInWithGoogle();
  Future<Either<Failure, UserModel>> signInWithFacebook();
  Future<Either<Failure, UserModel>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    File? avatarFile,
    String? referralCode,
  });
  Future<Either<Failure, UserModel>> completeProfile({
    required String userId,
    required String phone,
    File? avatarFile,
  });
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);
  Future<Either<Failure, void>> verifyPasswordResetOTP({
    required String email,
    required String otp,
  });
  Future<Either<Failure, void>> resetPassword(String newPassword);
  Future<Either<Failure, void>> deleteAccount();
  Future<Either<Failure, void>> signOut();
  UserModel? getCurrentUser();
}

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
  Future<Either<Failure, UserModel>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    File? avatarFile,
    String? referralCode,
  }) async {
    return await callRepository(() async {
      final user = await _remoteSource.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        avatarFile: avatarFile,
        referralCode: referralCode,
      );
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
  Future<Either<Failure, UserModel>> completeProfile({
    required String userId,
    required String phone,
    File? avatarFile,
  }) async {
    return await callRepository(() async {
      final user = await _remoteSource.completeProfile(
        userId: userId,
        phone: phone,
        avatarFile: avatarFile,
      );
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
