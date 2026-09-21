import 'package:flutter/material.dart';

import '../../../../art_core/models/time_range.dart';

/// Domain Service responsible for booking availability calculations,
/// status filtering, TimeRange parsing, operational hours calculation,
/// and conflict checking.
class BookingAvailabilityService {
  const BookingAvailabilityService();

  /// Parses a single raw booking row into a [TimeRange] entity or null if invalid/cancelled.
  TimeRange? parseBookingRow(Map<String, dynamic> b, DateTime date) {
    final status = b['status']?.toString().toLowerCase().trim();
    if (status == 'cancelled' ||
        status == 'rejected' ||
        status == 'declined' ||
        status == 'canceled') {
      return null;
    }

    // Ignore pending / pending_payment bookings older than 30 minutes
    if (status == 'pending' || status == 'pending_payment') {
      final createdAtStr = b['created_at']?.toString();
      if (createdAtStr != null) {
        final createdAt = DateTime.tryParse(createdAtStr);
        if (createdAt != null) {
          final age = DateTime.now().difference(createdAt.toLocal());
          if (age > const Duration(minutes: 30)) {
            return null; // Expired pending booking, does not block slot
          }
        }
      }
    }

    final startAt = b['start_at'] ?? b['start_time'];
    final endAt = b['end_at'] ?? b['end_time'];
    if (startAt == null || endAt == null) return null;

    final dateStr =
        b['date']?.toString() ??
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

  /// Calculates all 30-minute booked [TimeOfDay] slots for a list of [TimeRange]s on a given date.
  List<TimeOfDay> calculateBookedSlots(
    List<TimeRange> roomBookings,
    DateTime date,
  ) {
    final List<TimeOfDay> bookedSlots = [];

    for (int h = 0; h < 24; h++) {
      for (int m in const [0, 30]) {
        final slotDateTime = (h >= 10)
            ? DateTime(date.year, date.month, date.day, h, m)
            : DateTime(date.year, date.month, date.day + 1, h, m);
        final slotEnd = slotDateTime.add(const Duration(minutes: 30));

        final isOccupied = roomBookings.any(
          (range) =>
              range.start.isBefore(slotEnd) && range.end.isAfter(slotDateTime),
        );

        if (isOccupied) {
          bookedSlots.add(TimeOfDay(hour: h, minute: m));
        }
      }
    }

    return bookedSlots;
  }

  /// Checks if a proposed booking range (start + duration) conflicts with existing [TimeRange]s.
  bool isBookingConflicting({
    required List<TimeRange> roomBookings,
    required DateTime date,
    required TimeOfDay startTime,
    required int durationMinutes,
  }) {
    final startDateTime = (startTime.hour >= 10)
        ? DateTime(
            date.year,
            date.month,
            date.day,
            startTime.hour,
            startTime.minute,
          )
        : DateTime(
            date.year,
            date.month,
            date.day + 1,
            startTime.hour,
            startTime.minute,
          );
    final endDateTime = startDateTime.add(Duration(minutes: durationMinutes));

    return roomBookings.any(
      (range) =>
          range.start.isBefore(endDateTime) && range.end.isAfter(startDateTime),
    );
  }

  /// Parses raw booking rows and groups valid [TimeRange]s by `room_id`.
  Map<String, List<TimeRange>> groupBookedSlotsByRoom(
    List<Map<String, dynamic>> rawBookings,
    DateTime date,
  ) {
    final Map<String, List<TimeRange>> bookedSlotsByRoom = {};

    for (final b in rawBookings) {
      final range = parseBookingRow(b, date);
      if (range == null) continue;

      final roomId = b['room_id'].toString();
      bookedSlotsByRoom.putIfAbsent(roomId, () => []).add(range);
    }

    return bookedSlotsByRoom;
  }

  /// Calculates operational hours for a lounge based on `opensAt` and `closesAt` strings.
  double calculateOperationalHours(String opensAt, String closesAt) {
    if (!opensAt.contains(':') || !closesAt.contains(':')) return 16.0;

    try {
      final openParts = opensAt.split(':');
      final closeParts = closesAt.split(':');
      final openDuration = Duration(
        hours: int.parse(openParts[0]),
        minutes: int.parse(openParts[1]),
      );
      var closeDuration = Duration(
        hours: int.parse(closeParts[0]),
        minutes: int.parse(closeParts[1]),
      );

      if (closeDuration <= openDuration) {
        closeDuration += const Duration(days: 1);
      }

      return (closeDuration - openDuration).inMinutes / 60.0;
    } catch (_) {
      return 16.0;
    }
  }

  DateTime? _parseDateTime(String dateStr, String timeOrIsoStr) {
    if (timeOrIsoStr.contains('T') ||
        (timeOrIsoStr.contains('-') && timeOrIsoStr.contains(' '))) {
      final parsed = DateTime.tryParse(timeOrIsoStr.replaceFirst(' ', 'T'));
      if (parsed != null) {
        return DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
        );
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
