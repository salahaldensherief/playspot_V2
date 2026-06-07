import '../data_source/remote/home_remote_data_source.dart';
import '../../../lounge_details/data/extra_model.dart';
import '../models/lounge_model.dart';
import '../../../lounge_details/data/room_model.dart';

abstract class HomeRepository {
  Future<List<LoungeModel>> getLounges();
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId);
  Future<List<ExtraModel>> getExtras();
  Future<List<String>> getBookedRoomIds(String loungeId, DateTime start, DateTime end);
  Future<List<Map<String, dynamic>>> getBookingsForRoom(String roomId, DateTime date);
  Future<List<Map<String, dynamic>>> getBookingsForLounge(String loungeId, DateTime start, DateTime end);
  Future<void> createBooking({
    required String roomId,
    required String loungeId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
  });
}

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;

  HomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<LoungeModel>> getLounges() async {
    return await _remoteDataSource.getLounges();
  }

  @override
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId) async {
    return await _remoteDataSource.getRoomsByLoungeId(loungeId);
  }

  @override
  Future<List<ExtraModel>> getExtras() async {
    return await _remoteDataSource.getExtras();
  }

  @override
  Future<List<String>> getBookedRoomIds(String loungeId, DateTime start, DateTime end) async {
    return await _remoteDataSource.getBookedRoomIds(loungeId, start, end);
  }

  @override
  Future<List<Map<String, dynamic>>> getBookingsForRoom(String roomId, DateTime date) async {
    return await _remoteDataSource.getBookingsForRoom(roomId, date);
  }

  @override
  Future<List<Map<String, dynamic>>> getBookingsForLounge(String loungeId, DateTime start, DateTime end) async {
    return await _remoteDataSource.getBookingsForLounge(loungeId, start, end);
  }

  @override
  Future<void> createBooking({
    required String roomId,
    required String loungeId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
  }) async {
    await _remoteDataSource.createBooking(
      roomId: roomId,
      loungeId: loungeId,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
    );
  }
}
