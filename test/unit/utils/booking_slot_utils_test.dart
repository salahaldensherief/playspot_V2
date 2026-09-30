import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/utils/booking_slot_utils.dart';

void main() {
  group('BookingSlotUtils Tests', () {
    test('circularMinuteDistance calculates accurate distance within same half of day', () {
      const a = TimeOfDay(hour: 18, minute: 0);
      const b = TimeOfDay(hour: 18, minute: 30);
      expect(BookingSlotUtils.circularMinuteDistance(a, b), 30);
      expect(BookingSlotUtils.circularMinuteDistance(b, a), 30);
    });

    test('circularMinuteDistance correctly wraps around midnight boundary', () {
      // 23:30 to 00:30 is 60 minutes across midnight
      const lateNight = TimeOfDay(hour: 23, minute: 30);
      const earlyMorning = TimeOfDay(hour: 0, minute: 30);

      expect(
        BookingSlotUtils.circularMinuteDistance(lateNight, earlyMorning),
        60,
      );
      expect(
        BookingSlotUtils.circularMinuteDistance(earlyMorning, lateNight),
        60,
      );
    });

    test('circularMinuteDistance with 23:45 and 00:15 is 30 minutes', () {
      const a = TimeOfDay(hour: 23, minute: 45);
      const b = TimeOfDay(hour: 0, minute: 15);
      expect(BookingSlotUtils.circularMinuteDistance(a, b), 30);
    });

    test('circularMinuteDistance with opposite times (12h apart) is 720', () {
      const a = TimeOfDay(hour: 12, minute: 0);
      const b = TimeOfDay(hour: 0, minute: 0);
      expect(BookingSlotUtils.circularMinuteDistance(a, b), 720);
    });

    test('findClosestSlot picks 00:30 when target is 23:30 rather than far daytime slots', () {
      const target = TimeOfDay(hour: 23, minute: 30);
      const slots = [
        TimeOfDay(hour: 14, minute: 0),
        TimeOfDay(hour: 16, minute: 0),
        TimeOfDay(hour: 0, minute: 30), // 60 mins away
        TimeOfDay(hour: 2, minute: 0),
      ];

      final closest = BookingSlotUtils.findClosestSlot(slots, target);
      expect(closest, const TimeOfDay(hour: 0, minute: 30));
    });

    test('parseTimeOfDay parses HH:MM and HH:MM:SS correctly', () {
      expect(
        BookingSlotUtils.parseTimeOfDay('18:30'),
        const TimeOfDay(hour: 18, minute: 30),
      );
      expect(
        BookingSlotUtils.parseTimeOfDay('23:45:00'),
        const TimeOfDay(hour: 23, minute: 45),
      );
      expect(BookingSlotUtils.parseTimeOfDay(null), isNull);
      expect(BookingSlotUtils.parseTimeOfDay(''), isNull);
      expect(BookingSlotUtils.parseTimeOfDay('invalid'), isNull);
    });
  });
}
