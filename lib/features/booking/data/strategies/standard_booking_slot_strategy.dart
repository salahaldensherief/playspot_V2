import 'package:flutter/material.dart';
import '../../../../art_core/models/time_range.dart';
import '../../domain/strategies/booking_slot_strategy.dart';

class StandardBookingSlotStrategy implements BookingSlotStrategy {
  const StandardBookingSlotStrategy();

  @override
  List<TimeOfDay> calculateBookedSlots({
    required List<Map<String, dynamic>> rawBookings,
    required String roomId,
    required DateTime date,
  }) {
    final roomBookings = rawBookings
        .where((b) => b['room_id'].toString() == roomId)
        .map((b) => parseBookingRow(b, date))
        .whereType<TimeRange>()
        .toList();

    final List<TimeOfDay> bookedSlots = [];

    for (int h = 0; h < 24; h++) {
      for (int m in const [0, 30]) {
        final slotDateTime = (h >= 10)
            ? DateTime(date.year, date.month, date.day, h, m)
            : DateTime(date.year, date.month, date.day + 1, h, m);
        final slotEnd = slotDateTime.add(const Duration(minutes: 30));

        final isOccupied = roomBookings.any((range) =>
            range.start.isBefore(slotEnd) && range.end.isAfter(slotDateTime));

        if (isOccupied) {
          bookedSlots.add(TimeOfDay(hour: h, minute: m));
        }
      }
    }

    return bookedSlots;
  }

  @override
  bool isBookingConflicting({
    required List<Map<String, dynamic>> rawBookings,
    required String roomId,
    required DateTime date,
    required TimeOfDay startTime,
    required int durationMinutes,
  }) {
    final roomBookings = rawBookings
        .where((b) => b['room_id'].toString() == roomId)
        .map((b) => parseBookingRow(b, date))
        .whereType<TimeRange>()
        .toList();

    final startDateTime = (startTime.hour >= 10)
        ? DateTime(date.year, date.month, date.day, startTime.hour, startTime.minute)
        : DateTime(date.year, date.month, date.day + 1, startTime.hour, startTime.minute);
    final endDateTime = startDateTime.add(Duration(minutes: durationMinutes));

    return roomBookings.any((range) =>
        range.start.isBefore(endDateTime) && range.end.isAfter(startDateTime));
  }

  @override
  TimeRange? parseBookingRow(Map<String, dynamic> b, DateTime date) {
    final status = b['status']?.toString().toLowerCase().trim();
    if (status == 'cancelled' ||
        status == 'rejected' ||
        status == 'declined' ||
        status == 'canceled') {
      return null;
    }

    final startAt = b['start_at'] ?? b['start_time'];
    final endAt = b['end_at'] ?? b['end_time'];
    if (startAt == null || endAt == null) return null;

    final dateStr = b['date']?.toString() ??
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    try {
      final start = _parseDateTime(dateStr, startAt.toString());
      var end = _parseDateTime(dateStr, endAt.toString());
      if (start == null || end == null) return null;

      if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
        end = end.add(const Duration(days: 1));
      }

      return TimeRange(start: start, end: end);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDateTime(String dateStr, String timeOrIsoStr) {
    if (timeOrIsoStr.contains('T') || (timeOrIsoStr.contains('-') && timeOrIsoStr.contains(' '))) {
      final parsed = DateTime.tryParse(timeOrIsoStr.replaceFirst(' ', 'T'));
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute);
      }
    }

    final dateParts = dateStr.split('-');
    if (dateParts.length < 3) return null;
    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) return null;

    final timeParts = timeOrIsoStr.split(':');
    if (timeParts.length < 2) return null;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return null;

    return DateTime(year, month, day, hour, minute);
  }
}
