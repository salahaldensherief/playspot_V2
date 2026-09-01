import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../../data/models/user_model.dart';
import '../../data/models/auth_params.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserModel>> signInWithEmail({
    required String email,
    required String password,
  });
  Future<Either<Failure, UserModel>> signInWithGoogle();
  Future<Either<Failure, UserModel>> signInWithFacebook();
  Future<Either<Failure, UserModel>> signUpWithEmail(SignUpParams params);
  Future<Either<Failure, UserModel>> completeProfile(CompleteProfileParams params);
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
