import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../data_source/remote/booking_remote_data_source.dart';

abstract class BookingRepository {
  Future<Either<Failure, List<Map<String, dynamic>>>> getRoomBookingsForDate(String loungeId, DateTime date);
  Future<Either<Failure, void>> createBooking({
    required String roomId,
    required String roomName,
    required String loungeId,
    required String userName,
    required String userPhone,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
    required double roomPrice,
    List<Map<String, dynamic>> extras = const [],
    String? playMode,
  });
}

class BookingRepositoryImpl with RepositoryHelper implements BookingRepository {
  final BookingRemoteDataSource _remoteDataSource;

  BookingRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRoomBookingsForDate(String loungeId, DateTime date) async {
    return await callRepository(() => _remoteDataSource.getRoomBookingsForDate(loungeId, date));
  }

  @override
  Future<Either<Failure, void>> createBooking({
    required String roomId,
    required String roomName,
    required String loungeId,
    required String userName,
    required String userPhone,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
    required double roomPrice,
    List<Map<String, dynamic>> extras = const [],
    String? playMode,
  }) async {
    return await callRepository(() => _remoteDataSource.createBooking(
      roomId: roomId,
      roomName: roomName,
      loungeId: loungeId,
      userName: userName,
      userPhone: userPhone,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
      roomPrice: roomPrice,
      extras: extras,
      playMode: playMode,
    ));
  }
}
