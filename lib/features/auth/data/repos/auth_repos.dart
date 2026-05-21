import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/cache/preference_manager.dart';
import '../../data/models/user_model.dart';
import '../data_source/remote/auth_remote_data_source.dart';

abstract class AuthRepository {
  Future<Either<String, UserModel>> signInWithEmail({
    required String email,
    required String password,
  });
  Future<Either<String, UserModel>> signInWithGoogle();
  Future<Either<String, UserModel>> signInWithFacebook();

  Future<Either<String, UserModel>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    File? avatarFile,
  });
  Future<Either<String, UserModel>> signUpWithGoogle();
  Future<Either<String, UserModel>> signUpWithFacebook();

  Future<Either<String, UserModel>> completeProfile({
    required String userId,
    required String phone,
    File? avatarFile,
  });
  Future<Either<String, void>> sendPasswordResetEmail(String email);
  Future<Either<String, void>> verifyPasswordResetOTP({
    required String email,
    required String otp,
  });
  Future<Either<String, void>> resetPassword(String newPassword);

  Future<Either<String, void>> signOut();
  UserModel? getCurrentUser();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteSource _remoteSource;
  final PreferenceManager _preferenceManager;

  AuthRepositoryImpl(this._remoteSource, this._preferenceManager);

  void _saveUserData(UserModel user) {
    _preferenceManager.saveUserId(user.id);
    _preferenceManager.saveFullName(user.name);
    _preferenceManager.saveIsLoggedIn(true);
  }

  @override
  Future<Either<String, UserModel>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remoteSource.signInWithEmail(
        email: email,
        password: password,
      );
      _saveUserData(user);
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserModel>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    File? avatarFile,
  }) async {
    try {
      final user = await _remoteSource.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        avatarFile: avatarFile,
      );
      _saveUserData(user);
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserModel>> signUpWithGoogle() async {
    try {
      final user = await _remoteSource.signInWithGoogle();
      _saveUserData(user);
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserModel>> signUpWithFacebook() async {
    try {
      final user = await _remoteSource.signInWithFacebook();
      _saveUserData(user);
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserModel>> completeProfile({
    required String userId,
    required String phone,
    File? avatarFile,
  }) async {
    try {
      final user = await _remoteSource.completeProfile(
        userId: userId,
        phone: phone,
        avatarFile: avatarFile,
      );
      _saveUserData(user);
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserModel>> signInWithGoogle() async {
    try {
      final user = await _remoteSource.signInWithGoogle();
      _saveUserData(user);
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserModel>> signInWithFacebook() async {
    try {
      final user = await _remoteSource.signInWithFacebook();
      _saveUserData(user);
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, void>> signOut() async {
    try {
      await _remoteSource.signOut();
      _preferenceManager.saveIsLoggedIn(false);
      _preferenceManager.saveFullName(null);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  UserModel? getCurrentUser() {
    final user = _remoteSource.getCurrentUser();
    if (user != null) {
      _saveUserData(user);
    }
    return user;
  }
  @override
  Future<Either<String, void>> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    try {
      await _remoteSource.verifyPasswordResetOTP(email: email, otp: otp);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, void>> resetPassword(String newPassword) async {
    try {
      await _remoteSource.resetPassword(newPassword);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }
  @override
  Future<Either<String, void>> sendPasswordResetEmail(String email) async {
    try {
      await _remoteSource.sendPasswordResetEmail(email);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }
}