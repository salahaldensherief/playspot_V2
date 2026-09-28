import 'package:flutter/material.dart';
import '../../../../art_core/models/time_range.dart';
import '../../domain/services/booking_availability_service.dart';
import '../../domain/strategies/booking_slot_strategy.dart';

class StandardBookingSlotStrategy implements BookingSlotStrategy {
  final BookingAvailabilityService _availabilityService;

  const StandardBookingSlotStrategy([
    this._availabilityService = const BookingAvailabilityService(),
  ]);

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

    return _availabilityService.calculateBookedSlots(roomBookings, date);
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

    return _availabilityService.isBookingConflicting(
      roomBookings: roomBookings,
      date: date,
      startTime: startTime,
      durationMinutes: durationMinutes,
    );
  }

  @override
  TimeRange? parseBookingRow(Map<String, dynamic> b, DateTime date) {
    return _availabilityService.parseBookingRow(b, date);
  }
}
