part of 'active_session_cubit.dart';

extension _ActiveSessionStream on ActiveSessionCubit {
  void _subscribeToRealtime(String bookingId) {
    if (_subscribedBookingId == bookingId && _realtimeSubscription != null) {
      return;
    }

    dev.log(
      "[LIVESESSION_CUBIT] Subscribing to Realtime stream for booking: $bookingId",
    );
    _subscribedBookingId = bookingId;
    _realtimeSubscription?.cancel();

    _realtimeSubscription = subscribeWithRetry(
      streamFactory: () => _streamActiveSessionUseCase(bookingId),
      onData: (updatedSession) {
        if (isClosed || _subscribedBookingId != bookingId) return;
        ++_sessionLoadVersion;
        dev.log(
          "[LIVESESSION_CUBIT] REALTIME EVENT for $bookingId: status=${updatedSession.status}, end_time=${updatedSession.endTime}",
        );
        final status = BookingStatus.fromString(updatedSession.status);
        if (status == BookingStatus.completed ||
            status == BookingStatus.cancelled) {
          dev.log(
            "[LIVESESSION_CUBIT] Session ended or cancelled via Realtime",
          );
          try {
            LocalNotificationService.instance.cancelActiveSessionNotification();
            NativeNotificationService.instance.cancelCustomNotification();
            PlaySpotLiveActivityService.instance.endActivity();
          } catch (_) {}
          final completed = state.session ?? updatedSession;
          _clearSession(completed: completed);
          if (status == BookingStatus.completed) {
            _showGlobalReviewBottomSheet(completed);
          }
        } else {
          dev.log(
            "[LIVESESSION_CUBIT] Realtime update applied directly without re-fetching...",
          );
          final currentSession = state.session;
          final mergedSession = updatedSession.copyWith(
            loungeName: updatedSession.loungeName.isNotEmpty
                ? updatedSession.loungeName
                : currentSession?.loungeName ?? '',
            roomName: updatedSession.roomName.isNotEmpty
                ? updatedSession.roomName
                : currentSession?.roomName ?? '',
            orders: updatedSession.orders.isNotEmpty
                ? updatedSession.orders
                : currentSession?.orders ?? const [],
          );

          _publish(
            state.copyWith(
              status: ActiveSessionStatus.loaded,
              session: mergedSession,
            ),
          );

          try {
            PlaySpotLiveActivityService.instance.startActivity(
              sessionId: mergedSession.bookingId,
              hallName: mergedSession.loungeName.isNotEmpty
                  ? mergedSession.loungeName
                  : 'PlaySpot Lounge',
              deviceName: mergedSession.deviceName.isNotEmpty
                  ? mergedSession.deviceName
                  : mergedSession.roomName,
              endTimeTimestamp:
                  mergedSession.endTime.millisecondsSinceEpoch ~/ 1000,
            );

            final notificationId =
                mergedSession.bookingId.hashCode.abs() & 0x7FFFFFFF;
            LocalNotificationService.instance.scheduleSessionExpiryWarning(
              id: notificationId,
              loungeName: mergedSession.loungeName.isNotEmpty
                  ? mergedSession.loungeName
                  : 'Lounge',
              expiryTime: mergedSession.endTime,
            );
          } catch (_) {}
        }
      },
      onError: (err) {
        dev.log("[LIVESESSION_CUBIT] REALTIME STREAM ERROR: $err");
      },
      isClosedCheck: () => isClosed || _subscribedBookingId != bookingId,
      retryDelay: const Duration(seconds: 3),
      tag: 'LIVESESSION_REALTIME',
    );
  }
}
