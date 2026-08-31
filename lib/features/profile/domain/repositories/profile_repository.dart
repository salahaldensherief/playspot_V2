import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/redemption_option_model.dart';
import '../../data/models/profile_params.dart';

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
