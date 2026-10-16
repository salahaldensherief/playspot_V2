part of 'active_session_cubit.dart';

extension _ActiveSessionReview on ActiveSessionCubit {
  Future<Either<Failure, void>> _submitReviewImpl({
    required double rating,
    String? comment,
    ActiveSession? reviewSession,
  }) async {
    final session = reviewSession ?? state.completedSession ?? state.session;
    if (isClosed || session == null) {
      return const Left(ServerFailure(AppStrings.reviewSubmissionFailed));
    }
    final bookingId = session.bookingId;
    if (!_reviewSubmissions.add(bookingId)) {
      return const Left(ServerFailure(AppStrings.reviewSubmissionInProgress));
    }
    final epoch = _sessionEpoch;
    try {
      HapticFeedback.mediumImpact();
      final result = await _submitLoungeReviewUseCase(
        loungeId: session.loungeId,
        bookingId: bookingId,
        rating: rating,
        comment: comment,
      );
      final current =
          !isClosed &&
          epoch == _sessionEpoch &&
          (state.completedSession ?? state.session)?.bookingId == bookingId;
      await result.fold<Future<void>>(
        (failure) async {
          if (current) _publish(state.copyWith(errorMessage: failure.message));
        },
        (_) async {
          // Confirmed by the backend; finish the local cache write before
          // completing the review Future or disposing test plugin channels.
          await _markAsReviewed(bookingId);
          if (current) {
            _publish(
              state.copyWith(
                status: ActiveSessionStatus.empty,
                session: null,
                completedSession: null,
                errorMessage: null,
              ),
            );
          }
        },
      );
      return result;
    } catch (_) {
      return const Left(ServerFailure(AppStrings.reviewSubmissionFailed));
    } finally {
      _reviewSubmissions.remove(bookingId);
    }
  }
}
