import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../data_source/remote/home_remote_data_source.dart';
import '../../../lounge_details/data/extra_model.dart';
import '../models/lounge_model.dart';
import '../../../lounge_details/data/room_model.dart';

abstract class HomeRepository {
  Future<Either<Failure, List<LoungeModel>>> getLounges();
  Future<Either<Failure, List<RoomModel>>> getRoomsByLoungeId(String loungeId);
  Future<Either<Failure, List<ExtraModel>>> getExtras();
  Future<Either<Failure, List<String>>> getBookedRoomIds(String loungeId, DateTime start, DateTime end);
  Future<Either<Failure, List<Map<String, dynamic>>>> getBookingsForRoom(String roomId, DateTime date);
  Future<Either<Failure, List<Map<String, dynamic>>>> getBookingsForLounge(String loungeId, DateTime start, DateTime end);
  Future<Either<Failure, void>> createBooking({
    required String roomId,
    required String loungeId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
  });
}

class HomeRepositoryImpl with RepositoryHelper implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;

  HomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<LoungeModel>>> getLounges() async {
    return await callRepository(() => _remoteDataSource.getLounges());
  }

  @override
  Future<Either<Failure, List<RoomModel>>> getRoomsByLoungeId(String loungeId) async {
    return await callRepository(() => _remoteDataSource.getRoomsByLoungeId(loungeId));
  }

  @override
  Future<Either<Failure, List<ExtraModel>>> getExtras() async {
    return await callRepository(() => _remoteDataSource.getExtras());
  }

  @override
  Future<Either<Failure, List<String>>> getBookedRoomIds(String loungeId, DateTime start, DateTime end) async {
    return await callRepository(() => _remoteDataSource.getBookedRoomIds(loungeId, start, end));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getBookingsForRoom(String roomId, DateTime date) async {
    return await callRepository(() => _remoteDataSource.getBookingsForRoom(roomId, date));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getBookingsForLounge(String loungeId, DateTime start, DateTime end) async {
    return await callRepository(() => _remoteDataSource.getBookingsForLounge(loungeId, start, end));
  }

  @override
  Future<Either<Failure, void>> createBooking({
    required String roomId,
    required String loungeId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
  }) async {
    return await callRepository(() => _remoteDataSource.createBooking(
      roomId: roomId,
      loungeId: loungeId,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
    ));
  }
}
