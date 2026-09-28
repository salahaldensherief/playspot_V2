import 'package:flutter/material.dart';

/// Suggests the next visit on the same weekday, without reserving a slot.
class QuickRebookPreference {
  static DateTime nextVisitDate(DateTime previousDate, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    var daysAhead = (previousDate.weekday - today.weekday + 7) % 7;
    if (daysAhead == 0) daysAhead = 7;
    return DateTime(today.year, today.month, today.day + daysAhead);
  }

  static TimeOfDay? closestSlot(List<TimeOfDay> slots, String previousStart) {
    if (slots.isEmpty) return null;
    final parts = previousStart.split(':');
    if (parts.length < 2) return slots.first;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 ||
        minute < 0 || minute > 59) {
      return slots.first;
    }
    final target = hour * 60 + minute;
    var best = slots.first;
    var bestDistance = ((best.hour * 60 + best.minute) - target).abs();
    for (final slot in slots.skip(1)) {
      final distance = ((slot.hour * 60 + slot.minute) - target).abs();
      if (distance < bestDistance) {
        best = slot;
        bestDistance = distance;
      }
    }
    return best;
  }
}
