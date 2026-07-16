import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../data_source/remote/lounge_details_remote_data_source.dart';
import '../models/extra_model.dart';
import '../models/room_model.dart';

abstract class LoungeDetailsRepository {
  Future<Either<Failure, List<RoomModel>>> getRoomsByLoungeId(String loungeId);
  Future<Either<Failure, List<ExtraModel>>> getExtras();
}

class LoungeDetailsRepositoryImpl with RepositoryHelper implements LoungeDetailsRepository {
  final LoungeDetailsRemoteDataSource _remoteDataSource;

  LoungeDetailsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<RoomModel>>> getRoomsByLoungeId(String loungeId) async {
    return await callRepository(() => _remoteDataSource.getRoomsByLoungeId(loungeId));
  }

  @override
  Future<Either<Failure, List<ExtraModel>>> getExtras() async {
    return await callRepository(() => _remoteDataSource.getExtras());
  }
}
