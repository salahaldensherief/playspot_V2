import 'dart:developer' as dev;
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_status_entity.dart';
import '../../domain/repositories/app_status_repository.dart';
import '../datasources/remote/app_status_remote_data_source.dart';

class AppStatusRepositoryImpl implements AppStatusRepository {
  final AppStatusRemoteDataSource remoteDataSource;

  AppStatusRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, AppStatusEntity>> getAppStatus() async {
    try {
      final status = await remoteDataSource.getAppStatus();
      return Right(status);
    } catch (e) {
      dev.log('[AppStatusRepository] Error: $e');
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<AppStatusEntity> streamAppStatus() {
    return remoteDataSource.streamAppStatus();
  }
}
