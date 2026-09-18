import 'package:flutter/material.dart';
import '../../../../art_core/models/time_range.dart';

/// Abstract Strategy interface for calculating room booking slots and conflicts.
/// Decouples date-time calculations and overlap algorithms from state management (Cubit).
abstract class BookingSlotStrategy {
  /// Parses raw booking rows and calculates all occupied 30-minute time slots for a given date.
  List<TimeOfDay> calculateBookedSlots({
    required List<Map<String, dynamic>> rawBookings,
    required String roomId,
    required DateTime date,
  });

  /// Checks if a proposed booking range conflicts with existing room bookings.
  bool isBookingConflicting({
    required List<Map<String, dynamic>> rawBookings,
    required String roomId,
    required DateTime date,
    required TimeOfDay startTime,
    required int durationMinutes,
  });

  /// Parses a single booking row into a [TimeRange] entity or null if invalid/cancelled.
  TimeRange? parseBookingRow(Map<String, dynamic> row, DateTime date);
}
