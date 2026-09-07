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
          e.message.contains('no_overlapping_room_bookings') ||
          e.message.contains('prevent_room_booking_overlap')) {
        return Left(ServerFailure(AppStrings.overlappingBookingError.tr()));
      }

      if (e.code == '23505' ||
          e.message.toLowerCase().contains('unique constraint') ||
          e.message.toLowerCase().contains('already exists') ||
          e.message.toLowerCase().contains('duplicate key')) {
        if (e.message.contains('favorites')) {
          return Left(const ServerFailure("This lounge is already in your favorites."));
        }
        if (e.message.contains('review') || e.message.contains('booking')) {
          return Left(const ServerFailure("A review for this session has already been submitted."));
        }
        return Left(const ServerFailure("This record already exists."));
      }

      if (e.code == '42501' ||
          e.code == 'PGRST301' ||
          e.message.toLowerCase().contains('permission denied') ||
          e.message.toLowerCase().contains('invalid permission') ||
          e.message.toLowerCase().contains('row-level security') ||
          e.message.toLowerCase().contains('unauthorized') ||
          e.message.toLowerCase().contains('rls')) {
        return Left(const AuthFailure("Permission denied. Please verify your account access or role permissions."));
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
