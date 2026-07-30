import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../data_source/remote/home_remote_data_source.dart';
import '../models/lounge_model.dart';

abstract class HomeRepository {
  Future<Either<Failure, List<LoungeModel>>> getLounges({
    double? lat,
    double? lng,
  });
}

class HomeRepositoryImpl with RepositoryHelper implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;

  HomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<LoungeModel>>> getLounges({
    double? lat,
    double? lng,
  }) async {
    return await callRepository(() => _remoteDataSource.getLounges(
          lat: lat,
          lng: lng,
        ));
  }
}
