import '../entities/app_status_entity.dart';
import '../repositories/app_status_repository.dart';

class StreamAppStatusUseCase {
  final AppStatusRepository repository;

  StreamAppStatusUseCase(this.repository);

  Stream<AppStatusEntity> call() {
    return repository.streamAppStatus();
  }
}
