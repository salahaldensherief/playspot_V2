import '../entities/active_session.dart';
import '../repositories/active_session_repository.dart';

class StreamActiveSessionUseCase {
  final ActiveSessionRepository repository;

  StreamActiveSessionUseCase(this.repository);

  Stream<ActiveSession> call(String bookingId) {
    return repository.streamActiveSession(bookingId);
  }
}
