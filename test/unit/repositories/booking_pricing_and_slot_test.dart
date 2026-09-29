import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/booking/data/models/booking_price_quote_model.dart';
import 'package:playspot/features/booking/data/models/room_slot_price_model.dart';

void main() {
  group('Unified Pricing Engine Unit Tests', () {
    test('1. Pricing quote segments crossing midnight parse correctly with peak/off-peak rates', () {
      final jsonQuote = {
        "segments": [
          {
            "from": "22:00:00",
            "to": "00:00:00",
            "minutes": 120,
            "base_rate": 50.0,
            "applied_rule_id": "rule-peak-1",
            "rule_type": "peak",
            "rate": 70.0,
            "amount": 140.0,
          },
          {
            "from": "00:00:00",
            "to": "02:00:00",
            "minutes": 120,
            "base_rate": 50.0,
            "applied_rule_id": "rule-offpeak-2",
            "rule_type": "off_peak",
            "rate": 40.0,
            "amount": 80.0,
          }
        ],
        "room_subtotal": 220.0,
        "extra_controllers_amount": 0.0,
        "discount_amount": 0.0,
        "total": 220.0,
        "currency": "EGP",
        "has_peak": true,
        "pricing_version": 1
      };

      final quote = BookingPriceQuoteModel.fromJson(jsonQuote);

      expect(quote.segments.length, 2);
      expect(quote.hasPeak, isTrue);
      expect(quote.total, 220.0);

      final seg1 = quote.segments[0];
      expect(seg1.from, "22:00:00");
      expect(seg1.to, "00:00:00");
      expect(seg1.isPeak, isTrue);
      expect(seg1.amount, 140.0);

      final seg2 = quote.segments[1];
      expect(seg2.from, "00:00:00");
      expect(seg2.to, "02:00:00");
      expect(seg2.isPeak, isFalse);
      expect(seg2.amount, 80.0);
    });

    test('2. Unpriced slot (hourlyRate <= 0) is invalid and should be hidden from UI', () {
      final validSlotJson = {
        'slot_start': '14:00:00',
        'slot_end': '15:00:00',
        'is_available': true,
        'hourly_rate': 60.0,
        'rule_type': 'peak',
        'is_peak': true,
      };

      final unpricedSlotJson = {
        'slot_start': '15:00:00',
        'slot_end': '16:00:00',
        'is_available': true,
        'hourly_rate': 0.0, // Failed rule / unpriced slot
        'rule_type': 'standard',
        'is_peak': false,
      };

      final slot1 = RoomSlotPriceModel.fromJson(validSlotJson);
      final slot2 = RoomSlotPriceModel.fromJson(unpricedSlotJson);

      expect(slot1.isValidPriced, isTrue);
      expect(slot1.isPeak, isTrue);

      expect(slot2.isValidPriced, isFalse); // Filtered out, hidden in UI

      final slots = [slot1, slot2];
      final filteredSlots = slots.where((s) => s.isValidPriced).toList();

      expect(filteredSlots.length, 1);
      expect(filteredSlots.first.slotStart, '14:00:00');
    });

    test('3. PRICE_CHANGED failure maps old and new price quote correctly', () {
      final oldPrice = 120.0;
      final newPrice = 150.0;
      final failure = PriceChangedFailure(
        message: 'تغير سعر الساعات بناءً على قواعد الذروة الحالية',
        oldPrice: oldPrice,
        newPrice: newPrice,
      );

      expect(failure.message, contains('تغير سعر'));
      expect(failure.oldPrice, 120.0);
      expect(failure.newPrice, 150.0);
      expect(failure, isA<Failure>());
    });
  });
}
