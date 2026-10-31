part of 'active_session_cubit.dart';

extension _ActiveSessionUpsell on ActiveSessionCubit {
  Future<void> _recordUpsellImpressionImpl(UpsellSuggestion suggestion) async {
    final session = state.session;
    if (session == null || state.upsellImpressionsCount >= 2) return;

    _publish(
      state.copyWith(upsellImpressionsCount: state.upsellImpressionsCount + 1),
    );
    await _recordUpsellEventUseCase(
      ruleId: suggestion.ruleId,
      bookingId: session.bookingId,
      event: 'shown',
    );
  }

  Future<void> _dismissUpsellSuggestionImpl(UpsellSuggestion suggestion) async {
    final session = state.session;
    final updatedSuggestions = state.upsellSuggestions
        .where((s) => s.ruleId != suggestion.ruleId)
        .toList();
    _publish(state.copyWith(upsellSuggestions: updatedSuggestions));

    if (session != null) {
      await _recordUpsellEventUseCase(
        ruleId: suggestion.ruleId,
        bookingId: session.bookingId,
        event: 'dismissed',
      );
    }
  }

  Future<void> _acceptUpsellSuggestionImpl(
    UpsellSuggestion suggestion, {
    String? orderId,
    double? amount,
  }) async {
    final session = state.session;
    final updatedSuggestions = state.upsellSuggestions
        .where((s) => s.ruleId != suggestion.ruleId)
        .toList();
    _publish(state.copyWith(upsellSuggestions: updatedSuggestions));

    if (session != null) {
      await _recordUpsellEventUseCase(
        ruleId: suggestion.ruleId,
        bookingId: session.bookingId,
        event: 'accepted',
        canteenOrderId: orderId,
        amount: amount,
      );
    }
  }
}
