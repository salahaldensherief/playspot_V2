import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../art_core/app_strings.dart';
import '../../art_core/exceptions/app_exceptions.dart';
import '../error/failures.dart';

mixin RepositoryHelper {
  Future<Either<Failure, T>> callRepository<T>(Future<T> Function() call) async {
    try {
      final result = await call();
      return Right(result);
    } on PostgrestException catch (e) {
      if (e.code == '23P01' ||
          e.message.contains('exclusion constraint') ||
          e.message.contains('no_overlapping_room_bookings')) {
        return Left(ServerFailure(AppStrings.overlappingBookingError.tr()));
      }
      
      // Return error code in message for easier filtering in repositories if needed
      return Left(ServerFailure("${e.code}: ${e.message}"));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
