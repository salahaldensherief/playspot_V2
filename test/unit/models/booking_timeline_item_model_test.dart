import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/my_bookings/data/models/booking_timeline_item_model.dart';

void main() {
  group('BookingTimelineItemModel Unit Tests', () {
    test('1. fromJson correctly parses valid complete JSON', () {
      final json = {
        'id': 'evt_101',
        'event_code': 'booking_created',
        'title_ar': 'تم إنشاء الحجز',
        'title_en': 'Booking Placed',
        'occurred_at': '2026-09-29T10:00:00Z',
        'payload': {'total_price': 150, 'duration_hours': 2},
      };

      final model = BookingTimelineItemModel.fromJson(json);

      expect(model.id, 'evt_101');
      expect(model.eventCode, 'booking_created');
      expect(model.titleAr, 'تم إنشاء الحجز');
      expect(model.titleEn, 'Booking Placed');
      expect(model.payload?['total_price'], 150);
      expect(model.getTitle('ar'), 'تم إنشاء الحجز');
      expect(model.getTitle('en'), 'Booking Placed');
    });

    test('2. fromJson safely handles missing or null payload without breaking', () {
      final json = {
        'id': 'evt_102',
        'event_code': 'booking_approved',
        'title_ar': 'تمت الموافقة',
        'title_en': 'Approved',
        'occurred_at': '2026-09-29T10:05:00Z',
        'payload': null,
      };

      final model = BookingTimelineItemModel.fromJson(json);

      expect(model.id, 'evt_102');
      expect(model.payload, null);
      expect(model.getTitle('ar'), 'تمت الموافقة');
    });

    test('3. unknown event_code renders localized fallback title cleanly', () {
      final json = {
        'id': 'evt_999',
        'event_code': 'custom_unknown_action',
        'title_ar': '',
        'title_en': '',
        'occurred_at': '2026-09-29T12:00:00Z',
      };

      final model = BookingTimelineItemModel.fromJson(json);

      expect(model.eventCode, 'custom_unknown_action');
      expect(model.getTitle('ar'), 'تحديث بالحجز');
      expect(model.getTitle('en'), 'Booking Activity');
    });

    test('4. fromJson handles raw payload string or invalid JSON string defensively', () {
      final json = {
        'id': 'evt_103',
        'event_code': 'check_in',
        'occurred_at': null,
        'payload': 'invalid_json_string',
      };

      final model = BookingTimelineItemModel.fromJson(json);

      expect(model.id, 'evt_103');
      expect(model.payload, null);
      expect(model.occurredAt, isA<DateTime>());
    });
  });
}
