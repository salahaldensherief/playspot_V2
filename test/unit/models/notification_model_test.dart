import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/notifications/data/models/notification_model.dart';

void main() {
  group('NotificationModel Unit Tests', () {
    final nowIso = DateTime.now().toIso8601String();

    test('should parse notification from raw record with Arabic language', () {
      final json = {
        'id': 'notif_1',
        'title_ar': 'تم قبول الحجز! 🎉',
        'title_en': 'Booking Accepted! 🎉',
        'body_ar': 'تمت الموافقة على حجزك',
        'body_en': 'Your booking was approved',
        'type': 'booking',
        'is_read': false,
        'created_at': nowIso,
        'data': {'status': 'upcoming'},
      };

      final model = NotificationModel.fromRawRecord(json, 'ar');

      expect(model.id, 'notif_1');
      expect(model.title, 'تم قبول الحجز! 🎉');
      expect(model.body, 'تمت الموافقة على حجزك');
      expect(model.type, NotificationType.booking);
      expect(model.isRead, isFalse);
    });

    test('should infer status from text if status is missing in payload', () {
      final json = {
        'id': 'notif_2',
        'title': 'Booking Cancelled ❌',
        'body': 'Your booking was cancelled.',
        'type': 'booking',
        'is_read': true,
        'created_at': nowIso,
      };

      final model = NotificationModel.fromJson(json);

      expect(model.status, 'cancelled');
      expect(model.type, NotificationType.booking);
      expect(model.isRead, isTrue);
    });

    test('should correctly parse offer notification type', () {
      final json = {
        'id': 'notif_3',
        'title': 'Flash Sale Offer!',
        'body': '50% off on all games',
        'type': 'offer',
        'created_at': nowIso,
      };

      final model = NotificationModel.fromJson(json);

      expect(model.type, NotificationType.offer);
    });
  });
}
