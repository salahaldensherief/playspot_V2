import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Booking Pricing & Nighttime Slot Calculation', () {
    test('nighttime session spanning past midnight calculates correct duration', () {
      final start = DateTime(2026, 3, 27, 23, 30);
      final end = DateTime(2026, 3, 28, 1, 30);
      final duration = end.difference(start).inMinutes;
      expect(duration, 120);
    });

    test('manual discount is subtracted from total price subtotal', () {
      const roomPrice = 100.0;
      const addonsPrice = 50.0;
      const discountAmount = 20.0;
      final subtotal = roomPrice + addonsPrice;
      final totalPrice = (subtotal - discountAmount).clamp(0.0, double.infinity);
      expect(totalPrice, 130.0);
    });
  });
}
