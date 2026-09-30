import 'package:flutter/material.dart';

class BookingSlotUtils {
  const BookingSlotUtils._();

  /// Calculates the shortest distance in minutes between two [TimeOfDay] points
  /// on a circular 24-hour clock (1440 minutes).
  ///
  /// Handles midnight-boundary crossovers accurately:
  /// - 23:30 to 00:30 is 60 minutes
  /// - 00:15 to 23:45 is 30 minutes
  /// - 18:00 to 18:30 is 30 minutes
  static int circularMinuteDistance(TimeOfDay a, TimeOfDay b) {
    final aMin = a.hour * 60 + a.minute;
    final bMin = b.hour * 60 + b.minute;
    final diff = (aMin - bMin).abs() % 1440;
    return diff > 720 ? 1440 - diff : diff;
  }

  /// Finds the slot in [slots] that is closest to [target] using circular 24h distance.
  static TimeOfDay findClosestSlot(List<TimeOfDay> slots, TimeOfDay target) {
    if (slots.isEmpty) return target;
    TimeOfDay closest = slots.first;
    int minDistance = circularMinuteDistance(closest, target);

    for (int i = 1; i < slots.length; i++) {
      final slot = slots[i];
      final distance = circularMinuteDistance(slot, target);
      if (distance < minDistance) {
        minDistance = distance;
        closest = slot;
      }
    }
    return closest;
  }

  /// Parses a time string (e.g. "18:00:00" or "23:30") into a [TimeOfDay].
  static TimeOfDay? parseTimeOfDay(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  /// Resolves the intended slot time from booking string or DateTime.
  static TimeOfDay resolveTargetTime(String? rawTime, DateTime fallbackDateTime) {
    final parsed = parseTimeOfDay(rawTime);
    if (parsed != null) return parsed;
    return TimeOfDay(
      hour: fallbackDateTime.hour,
      minute: fallbackDateTime.minute,
    );
  }

  /// Generates ordered candidate dates within 14 days, prioritizing matching weekday.
  static List<DateTime> buildCandidateDates(DateTime today, int preferredWeekday) {
    final list = <DateTime>[];

    // 1. Same weekday occurrences in next 14 days
    for (int i = 1; i <= 14; i++) {
      final d = today.add(Duration(days: i));
      if (d.weekday == preferredWeekday) {
        list.add(d);
      }
    }

    // 2. Sequential days from tomorrow up to 14 days
    for (int i = 1; i <= 14; i++) {
      final d = today.add(Duration(days: i));
      final exists = list.any(
        (existing) =>
            existing.year == d.year &&
            existing.month == d.month &&
            existing.day == d.day,
      );
      if (!exists) {
        list.add(d);
      }
    }
    return list;
  }
}
