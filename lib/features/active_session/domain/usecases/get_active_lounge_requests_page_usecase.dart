import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../repositories/active_session_repository.dart';

class GetActiveLoungeRequestsPageUseCase {
  final ActiveSessionRepository repository;

  GetActiveLoungeRequestsPageUseCase(this.repository);

  Future<Either<Failure, PaginatedResponse<Map<String, dynamic>>>> call({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
  }) {
    return repository.getActiveLoungeRequestsPage(
      loungeId: loungeId,
      page: page,
      pageSize: pageSize,
    );
  }
}
