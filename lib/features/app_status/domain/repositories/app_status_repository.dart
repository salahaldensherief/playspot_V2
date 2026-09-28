import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/app_status_entity.dart';

abstract class AppStatusRepository {
  Future<Either<Failure, AppStatusEntity>> getAppStatus();
  Stream<AppStatusEntity> streamAppStatus();
}
