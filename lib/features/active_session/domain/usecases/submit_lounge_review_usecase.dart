import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/active_session_repository.dart';

class SubmitLoungeReviewUseCase {
  final ActiveSessionRepository repository;

  SubmitLoungeReviewUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String loungeId,
    required String bookingId,
    required double rating,
    String? comment,
  }) {
    return repository.submitLoungeReview(
      loungeId: loungeId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
    );
  }
}
