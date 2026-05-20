import '../data_source/remote/home_remote_data_source.dart';
import '../../../lounge_details/data/extra_model.dart';
import '../models/lounge_model.dart';
import '../../../lounge_details/data/room_model.dart';

abstract class HomeRepository {
  Future<List<LoungeModel>> getLounges();
  Future<List<RoomModel>> getRoomsByLoungeId(String loungeId);
  Future<List<ExtraModel>> getExtras();
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
}
