part of 'active_session_cubit.dart';

extension _ActiveSessionExtension on ActiveSessionCubit {
  Future<void> _requestExtensionImpl(int requestedMinutes) async {
    final active = state.session;
    if (isClosed ||
        active == null ||
        state.extendStatus == ActionStatus.loading) {
      return;
    }

    HapticFeedback.mediumImpact();

    final bookingId = active.bookingId;
    final epoch = _sessionEpoch;
    dev.log(
      "[LIVESESSION_CUBIT] REQUEST_EXTENSION: bookingId=$bookingId, minutes=$requestedMinutes",
    );

    _publish(state.copyWith(extendStatus: ActionStatus.loading));

    final result = await _requestSessionExtensionUseCase(
      bookingId: bookingId,
      requestedMinutes: requestedMinutes,
    );

    if (isClosed ||
        epoch != _sessionEpoch ||
        state.session?.bookingId != bookingId) {
      return;
    }

    result.fold(
      (failure) {
        dev.log(
          "[LIVESESSION_CUBIT] REQUEST_EXTENSION FAILURE: ${failure.message}",
        );
        _publish(
          state.copyWith(
            extendStatus: ActionStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (_) {
        dev.log("[LIVESESSION_CUBIT] REQUEST_EXTENSION SUCCESS");
        _publish(state.copyWith(extendStatus: ActionStatus.success));
        loadActiveSession(bookingId: bookingId);
      },
    );
  }

  Future<void> _requestStaffAssistanceImpl(String type, String? notes) async {
    final session = state.session;
    if (isClosed ||
        session == null ||
        state.staffRequestStatus == ActionStatus.loading) {
      return;
    }

    HapticFeedback.mediumImpact();

    final bookingId = session.bookingId;
    final epoch = _sessionEpoch;
    dev.log(
      "[LIVESESSION_CUBIT] REQUEST_STAFF_ASSISTANCE: bookingId=$bookingId, type=$type",
    );

    _publish(state.copyWith(staffRequestStatus: ActionStatus.loading));

    final result = await _requestStaffAssistanceUseCase(
      bookingId: bookingId,
      callType: type,
      notes: notes,
    );

    if (isClosed ||
        epoch != _sessionEpoch ||
        state.session?.bookingId != bookingId) {
      return;
    }

    result.fold(
      (failure) {
        dev.log(
          "[LIVESESSION_CUBIT] REQUEST_STAFF_ASSISTANCE FAILURE: ${failure.message}",
        );
        _publish(
          state.copyWith(
            staffRequestStatus: ActionStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (_) {
        dev.log("[LIVESESSION_CUBIT] REQUEST_STAFF_ASSISTANCE SUCCESS");
        _publish(state.copyWith(staffRequestStatus: ActionStatus.success));
      },
    );
  }
}
