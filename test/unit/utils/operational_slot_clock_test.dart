import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/booking/domain/services/operational_slot_clock.dart';

void main() {
  const clock = OperationalSlotClock();
  final day = DateTime(2030, 1, 31);

  test('overnight early-morning slot belongs to the following date', () {
    expect(
      clock.resolve(
        businessDate: day,
        slot: const TimeOfDay(hour: 1, minute: 30),
        opensAt: '18:00',
        closesAt: '03:00',
      ),
      DateTime(2030, 2, 1, 1, 30),
    );
  });

  test('morning venue does not shift morning slots to tomorrow', () {
    expect(
      clock.resolve(
        businessDate: day,
        slot: const TimeOfDay(hour: 8, minute: 0),
        opensAt: '07:00',
        closesAt: '22:00',
      ),
      DateTime(2030, 1, 31, 8),
    );
  });

  test('opening slot of a 24-hour venue stays on its business date', () {
    expect(
      clock.resolve(
        businessDate: day,
        slot: const TimeOfDay(hour: 9, minute: 0),
        opensAt: '09:00',
        closesAt: '09:00',
      ),
      DateTime(2030, 1, 31, 9),
    );
  });

  test('invalid operating hours do not invent a day offset', () {
    expect(
      clock.resolve(
        businessDate: day,
        slot: const TimeOfDay(hour: 1, minute: 0),
        opensAt: '-1:00',
        closesAt: '03:00',
      ),
      DateTime(2030, 1, 31, 1),
    );
  });
}
