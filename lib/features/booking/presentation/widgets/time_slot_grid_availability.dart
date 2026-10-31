part of 'time_slot_grid.dart';

extension _TimeSlotAvailability on _TimeSlotGridState {
  List<TimeOfDay> _generateFutureSlots(
    String openStr,
    String closeStr,
    BookingState state,
  ) {
    int start = _parseHour(openStr, 10);
    int end = _parseHour(closeStr, 2);

    if (end <= start) {
      end += 24;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );
    final isToday = selectedDate.isAtSameMomentAs(today);
    final isPastDate = selectedDate.isBefore(today);

    if (isPastDate) return [];

    final List<TimeOfDay> list = [];
    for (int h = start; h < end; h++) {
      final hourMod = h % 24;
      for (int m = 0; m < 60; m += 15) {
        final slot = TimeOfDay(hour: hourMod, minute: m);

        if (isToday) {
          var slotDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            slot.hour,
            slot.minute,
          );
          if (slot.hour < 6) {
            slotDateTime = slotDateTime.add(const Duration(days: 1));
          }
          if (slotDateTime.isBefore(now.add(const Duration(minutes: 5)))) {
            continue;
          }
        }

        // Rule #2: if slotPrices is available and slot price rate <= 0 (unpriced slot), hide it!
        if (state.slotPrices.isNotEmpty) {
          final slotPrice = state.getSlotPrice(slot);
          if (slotPrice != null && !slotPrice.isValidPriced) {
            continue; // Hide slot!
          }
        }

        list.add(slot);
      }
    }
    return list;
  }

  bool _isSlotBooked(TimeOfDay slot, BookingState state) {
    return state.bookedTimeSlots.any(
      (b) => b.hour == slot.hour && b.minute == slot.minute,
    );
  }

  double _calculateMaxContinuousFreeHours(
    TimeOfDay start,
    List<TimeOfDay> allSlots,
    BookingState state,
  ) {
    final startIndex = allSlots.indexWhere(
      (s) => s.hour == start.hour && s.minute == start.minute,
    );
    if (startIndex == -1) return 0.0;

    int count = 0;
    for (int i = startIndex; i < allSlots.length; i++) {
      if (_isSlotBooked(allSlots[i], state)) break;
      count++;
    }
    return (count * 15) / 60.0;
  }

  bool _isPartOfCurrentSelection(TimeOfDay slot, BookingState state) {
    if (state.startTime == null) return false;

    final startMinutes = state.startTime!.hour * 60 + state.startTime!.minute;
    final slotMinutes = slot.hour * 60 + slot.minute;

    int normalizedStart = startMinutes;
    if (startMinutes < (6 * 60)) normalizedStart += (24 * 60);

    int normalizedSlot = slotMinutes;
    if (slotMinutes < (6 * 60)) normalizedSlot += (24 * 60);

    final normalizedEnd = normalizedStart + state.durationMinutes;

    return normalizedSlot >= normalizedStart && normalizedSlot < normalizedEnd;
  }

  int _parseHour(String str, int defaultHour) {
    if (str.isEmpty) return defaultHour;
    try {
      final parts = str.split(':');
      return int.parse(parts[0]);
    } catch (_) {
      return defaultHour;
    }
  }

  String _formatTime(TimeOfDay time) =>
      MaterialLocalizations.of(context).formatTimeOfDay(time);
}
