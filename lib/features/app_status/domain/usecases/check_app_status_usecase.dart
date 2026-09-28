import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/app_status_entity.dart';
import '../repositories/app_status_repository.dart';

class CheckAppStatusUseCase {
  final AppStatusRepository repository;

  CheckAppStatusUseCase(this.repository);

  Future<Either<Failure, AppStatusEntity>> call() async {
    return await repository.getAppStatus();
  }
}
