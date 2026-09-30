part of 'active_session_cubit.dart';

extension _ActiveSessionReview on ActiveSessionCubit {
  Future<void> _submitReviewImpl({
    required double rating,
    String? comment,
  }) async {
    final session = state.session ?? state.completedSession;
    if (isClosed || session == null) return;

    HapticFeedback.mediumImpact();

    final bookingId = session.bookingId;
    final epoch = _sessionEpoch;
    dev.log(
      "[LIVESESSION_CUBIT] SUBMIT_REVIEW: bookingId=$bookingId, rating=$rating",
    );

    final result = await _submitLoungeReviewUseCase(
      loungeId: session.loungeId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
    );

    if (isClosed ||
        epoch != _sessionEpoch ||
        (state.session ?? state.completedSession)?.bookingId != bookingId)
      return;

    result.fold(
      (failure) {
        dev.log(
          "[LIVESESSION_CUBIT] SUBMIT_REVIEW FAILURE: ${failure.message}",
        );
        _publish(state.copyWith(errorMessage: failure.message));
      },
      (_) {
        dev.log("[LIVESESSION_CUBIT] SUBMIT_REVIEW SUCCESS");
        _publish(
          state.copyWith(
            status: ActiveSessionStatus.empty,
            session: null,
            completedSession: null,
          ),
        );
      },
    );
  }
}
