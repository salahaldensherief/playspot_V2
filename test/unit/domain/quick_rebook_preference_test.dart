import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/my_bookings/domain/quick_rebook_preference.dart';

void main() {
  test('suggests the next matching weekday, including seven days from today', () {
    expect(
      QuickRebookPreference.nextVisitDate(
        DateTime(2026, 9, 18),
        DateTime(2026, 9, 28, 20),
      ),
      DateTime(2026, 10, 2),
    );
    expect(
      QuickRebookPreference.nextVisitDate(
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 28),
      ),
      DateTime(2026, 10, 5),
    );
  });

  test('prefers the previous time and falls back for invalid time', () {
    final slots = [
      const TimeOfDay(hour: 18, minute: 0),
      const TimeOfDay(hour: 20, minute: 30),
      const TimeOfDay(hour: 21, minute: 30),
    ];
    expect(QuickRebookPreference.closestSlot(slots, '21:00:00'), slots[1]);
    expect(QuickRebookPreference.closestSlot(slots, 'bad'), slots.first);
    expect(QuickRebookPreference.closestSlot([], '21:00'), isNull);
  });
}
