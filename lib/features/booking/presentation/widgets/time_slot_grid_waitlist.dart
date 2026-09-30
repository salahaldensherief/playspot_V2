part of 'time_slot_grid.dart';

extension _TimeSlotWaitlist on _TimeSlotGridState {
  Future<void> _requestWaitlist(BuildContext context, TimeOfDay slot) async {
    if (_waitlistBusy) return;
    _waitlistBusy = true;
    try {
      final cubit = context.read<BookingCubit>();
      final (loaded, activeId) = await cubit.activeWaitlistRequest(slot);
      if (!mounted) return;
      if (!loaded) {
        _showWaitlistMessage(AppStrings.waitlistFailed);
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            (activeId == null
                    ? AppStrings.waitlistNotify
                    : AppStrings.waitlistCancel)
                .tr(),
          ),
          content: Text(
            (activeId == null
                    ? AppStrings.waitlistExplain
                    : AppStrings.waitlistCancelExplain)
                .tr(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppStrings.cancel.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                (activeId == null
                        ? AppStrings.waitlistNotify
                        : AppStrings.waitlistCancel)
                    .tr(),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final messageKey = activeId == null
          ? await cubit.joinWaitlist(slot)
          : await cubit.cancelWaitlist(activeId);
      if (!mounted) return;
      if (messageKey == 'waitlistJoined') {
        _updateWaitlist(() {
          _waitlistedSlotKeys.add(_slotKey(cubit.state.selectedDate, slot));
        });
      } else if (messageKey == 'waitlistCancelled') {
        _updateWaitlist(() {
          _waitlistedSlotKeys.remove(_slotKey(cubit.state.selectedDate, slot));
        });
      }
      _showWaitlistMessage(messageKey);
    } finally {
      _waitlistBusy = false;
    }
  }

  void _showWaitlistMessage(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(key.tr())));
  }
}
