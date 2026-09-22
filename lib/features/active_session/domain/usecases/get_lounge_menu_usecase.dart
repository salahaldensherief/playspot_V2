import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../lounge_details/data/models/extra_model.dart';
import '../repositories/active_session_repository.dart';

class GetLoungeMenuUseCase {
  final ActiveSessionRepository repository;

  GetLoungeMenuUseCase(this.repository);

  Future<Either<Failure, List<ExtraModel>>> call({
    required String loungeId,
    bool forceRefresh = false,
  }) {
    return repository.getLoungeMenu(loungeId, forceRefresh: forceRefresh);
  }
}
