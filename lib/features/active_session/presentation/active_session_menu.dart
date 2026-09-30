part of 'active_session_cubit.dart';

extension _ActiveSessionMenu on ActiveSessionCubit {
  Future<void> _loadMenuImpl(
    String loungeId, {
    bool forceRefresh = false,
  }) async {
    if (loungeId.isEmpty || isClosed) return;
    if (state.session != null && state.session?.loungeId != loungeId) return;
    if (!forceRefresh &&
        state.menu.isNotEmpty &&
        _loadedMenuLoungeId == loungeId) {
      return;
    }
    dev.log("[LIVESESSION_CUBIT] LOAD_CANTEEN_MENU for lounge: $loungeId");
    if (_requestedMenuLoungeId != loungeId) {
      _publish(
        state.copyWith(menu: [], combos: [], menuStatus: ActionStatus.initial),
      );
    }
    _requestedMenuLoungeId = loungeId;
    _publish(state.copyWith(menuStatus: ActionStatus.loading));
    final menuVersion = ++_menuLoadVersion;
    final result = await _getCanteenMenuUseCase(loungeId: loungeId);
    if (isClosed ||
        menuVersion != _menuLoadVersion ||
        (state.session != null && state.session?.loungeId != loungeId))
      return;
    result.fold(
      (f) {
        dev.log("[LIVESESSION_CUBIT] LOAD_CANTEEN_MENU FAILURE: ${f.message}");
        _publish(state.copyWith(menuStatus: ActionStatus.error));
      },
      (canteenMenu) {
        _loadedMenuLoungeId = loungeId;
        dev.log(
          "[LIVESESSION_CUBIT] LOAD_CANTEEN_MENU SUCCESS: ${canteenMenu.extras.length} items, ${canteenMenu.combos.length} combos",
        );
        _publish(
          state.copyWith(
            menu: canteenMenu.extras,
            combos: canteenMenu.combos,
            menuStatus: ActionStatus.success,
          ),
        );
      },
    );
  }

  Future<void> _loadUpsellSuggestionsImpl(String bookingId) async {
    if (bookingId.isEmpty || isClosed) return;
    if (state.upsellImpressionsCount >= 2) return;

    final upsellVersion = ++_upsellLoadVersion;
    final result = await _getUpsellSuggestionsUseCase(bookingId: bookingId);
    if (isClosed ||
        upsellVersion != _upsellLoadVersion ||
        state.session?.bookingId != bookingId)
      return;

    result.fold(
      (f) => dev.log("[LIVESESSION_CUBIT] LOAD_UPSELL FAILURE: ${f.message}"),
      (suggestions) {
        _publish(state.copyWith(upsellSuggestions: suggestions));
      },
    );
  }
}
