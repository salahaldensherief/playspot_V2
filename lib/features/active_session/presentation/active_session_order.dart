part of 'active_session_cubit.dart';

extension _ActiveSessionOrder on ActiveSessionCubit {
  Future<void> _placeOrderImpl(List<OrderItem> items) async {
    final session = state.session;
    if (isClosed ||
        session == null ||
        state.orderStatus == ActionStatus.loading)
      return;

    HapticFeedback.mediumImpact();

    final bookingId = session.bookingId;
    final epoch = _sessionEpoch;
    dev.log(
      "[LIVESESSION_CUBIT] PLACE_ORDER: bookingId=$bookingId, itemsCount=${items.length}",
    );

    _publish(
      state.copyWith(orderStatus: ActionStatus.loading, unavailableItems: []),
    );

    final result = await _placeSessionOrderUseCase(
      bookingId: bookingId,
      items: items,
    );

    if (isClosed ||
        epoch != _sessionEpoch ||
        state.session?.bookingId != bookingId)
      return;

    result.fold(
      (failure) {
        dev.log("[LIVESESSION_CUBIT] PLACE_ORDER FAILURE: ${failure.message}");
        if (failure is CanteenOutOfStockFailure) {
          _publish(
            state.copyWith(
              orderStatus: ActionStatus.error,
              errorMessage: failure.message,
              unavailableItems: failure.unavailableItems
                  .whereType<OutOfStockItem>()
                  .toList(),
            ),
          );
        } else {
          _publish(
            state.copyWith(
              orderStatus: ActionStatus.error,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (_) {
        dev.log("[LIVESESSION_CUBIT] PLACE_ORDER SUCCESS");
        _publish(
          state.copyWith(
            orderStatus: ActionStatus.success,
            unavailableItems: [],
          ),
        );
        loadActiveSession(bookingId: bookingId);
      },
    );
  }
}
