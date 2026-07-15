import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/cache/preference_manager.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../data/models/user_model.dart';
import '../data_source/remote/auth_remote_data_source.dart';

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
  });
  Future<Either<Failure, UserModel>> signUpWithGoogle();
  Future<Either<Failure, UserModel>> signUpWithFacebook();

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

  Future<Either<Failure, void>> signOut();
  UserModel? getCurrentUser();
}

class AuthRepositoryImpl with RepositoryHelper implements AuthRepository {
  final AuthRemoteSource _remoteSource;
  final PreferenceManager _preferenceManager;

  AuthRepositoryImpl(this._remoteSource, this._preferenceManager);

  void _saveUserData(UserModel user) {
    _preferenceManager.saveUserId(user.id);
    _preferenceManager.saveFullName(user.name);
    _preferenceManager.saveIsLoggedIn(true);
  }

  @override
  Future<Either<Failure, UserModel>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await callRepository(() async {
      final user = await _remoteSource.signInWithEmail(
        email: email,
        password: password,
      );
      _saveUserData(user);
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
  }) async {
    return await callRepository(() async {
      final user = await _remoteSource.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        avatarFile: avatarFile,
      );
      _saveUserData(user);
      return user;
    });
  }

  @override
  Future<Either<Failure, UserModel>> signUpWithGoogle() async {
    return await callRepository(() async {
      final user = await _remoteSource.signInWithGoogle();
      _saveUserData(user);
      return user;
    });
  }

  @override
  Future<Either<Failure, UserModel>> signUpWithFacebook() async {
    return await callRepository(() async {
      final user = await _remoteSource.signInWithFacebook();
      _saveUserData(user);
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
      _saveUserData(user);
      return user;
    });
  }

  @override
  Future<Either<Failure, UserModel>> signInWithGoogle() async {
    return await callRepository(() async {
      final user = await _remoteSource.signInWithGoogle();
      _saveUserData(user);
      return user;
    });
  }

  @override
  Future<Either<Failure, UserModel>> signInWithFacebook() async {
    return await callRepository(() async {
      final user = await _remoteSource.signInWithFacebook();
      _saveUserData(user);
      return user;
    });
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    return await callRepository(() async {
      await _remoteSource.signOut();
      _preferenceManager.saveIsLoggedIn(false);
      _preferenceManager.saveFullName(null);
    });
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
  Future<Either<Failure, void>> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    return await callRepository(() async {
      await _remoteSource.verifyPasswordResetOTP(email: email, otp: otp);
    });
  }

  @override
  Future<Either<Failure, void>> resetPassword(String newPassword) async {
    return await callRepository(() async {
      await _remoteSource.resetPassword(newPassword);
    });
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    return await callRepository(() async {
      await _remoteSource.sendPasswordResetEmail(email);
    });
  }
}
