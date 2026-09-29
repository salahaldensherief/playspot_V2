import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/upsell_suggestion.dart';
import '../repositories/active_session_repository.dart';

class GetUpsellSuggestionsUseCase {
  final ActiveSessionRepository repository;

  GetUpsellSuggestionsUseCase(this.repository);

  Future<Either<Failure, List<UpsellSuggestion>>> call({required String bookingId}) {
    return repository.getUpsellSuggestions(bookingId);
  }
}
