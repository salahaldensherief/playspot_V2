import 'dart:io';

import 'package:dartz/dartz.dart';

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

  Future<Either<String, void>> signOut();
  UserModel? getCurrentUser();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteSource _remoteSource;

  AuthRepositoryImpl(this._remoteSource);

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
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserModel>> signUpWithGoogle() async {
    try {
      final user = await _remoteSource.signInWithGoogle();
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserModel>> signUpWithFacebook() async {
    try {
      final user = await _remoteSource.signInWithFacebook();
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
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserModel>> signInWithGoogle() async {
    try {
      final user = await _remoteSource.signInWithGoogle();
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, UserModel>> signInWithFacebook() async {
    try {
      final user = await _remoteSource.signInWithFacebook();
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, void>> signOut() async {
    try {
      await _remoteSource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  UserModel? getCurrentUser() {
    return _remoteSource.getCurrentUser();
  }
}