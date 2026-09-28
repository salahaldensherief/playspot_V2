import '../entities/active_session.dart';
import '../repositories/active_session_repository.dart';

class WatchUserActiveSessionUseCase {
  final ActiveSessionRepository repository;

  WatchUserActiveSessionUseCase(this.repository);

  Stream<ActiveSession?> call() {
    return repository.watchUserActiveSession();
  }
}
