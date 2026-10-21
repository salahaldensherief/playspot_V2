import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/active_session/data/models/active_session_model.dart';

void main() {
  group('ActiveSessionModel Unit Tests', () {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 30));
    final endTime = now.add(const Duration(minutes: 30));

    final testJson = {
      'id': 'booking_123',
      'lounge_id': 'lounge_456',
      'lounge_name': 'Gamed Lounge',
      'room_name': 'VIP Room 1',
      'device_name': 'PlayStation 5',
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'base_price': 150.0,
      'total_price': 280.0,
      'extensions_price': 50.0,
      'status': 'in_progress',
      'booking_items': [
        {
          'id': 'item_1',
          'name': 'Red Bull',
          'price': 40.0,
          'quantity': 2,
          'note': 'Ice please',
        },
      ],
    };

    test('should correctly parse ActiveSessionModel from JSON', () {
      final model = ActiveSessionModel.fromJson(testJson);

      expect(model.bookingId, 'booking_123');
      expect(model.loungeId, 'lounge_456');
      expect(model.loungeName, 'Gamed Lounge');
      expect(model.roomName, 'VIP Room 1');
      expect(model.basePrice, 150.0);
      expect(model.extensionsPrice, 50.0);
      expect(model.orders.length, 1);
      expect(model.orders.first.name, 'Red Bull');
      expect(model.orders.first.total, 80.0);
      expect(model.status, 'in_progress');
    });

    test('should calculate grandTotal correctly including orders', () {
      final model = ActiveSessionModel.fromJson(testJson);

      // basePrice (150) + extensionsPrice (50) + ordersTotal (80) = 280
      expect(model.ordersTotal, 80.0);
      expect(model.grandTotal, 280.0);
    });

    test(
      'uses the server end time without adding approved extension twice',
      () {
        final model = ActiveSessionModel.fromJson({
          'id': 'extended',
          'date': '2026-10-21',
          'start_time': '15:00:00',
          'end_time': '16:30:00',
          'duration_minutes': 90,
          'extended_minutes': 30,
        });

        expect(
          model.endTime.difference(model.startTime),
          const Duration(minutes: 90),
        );
      },
    );

    test('reads a session ending after midnight as the next day', () {
      final model = ActiveSessionModel.fromJson({
        'id': 'overnight',
        'date': '2026-10-21',
        'start_time': '23:30:00',
        'end_time': '00:30:00',
        'duration_minutes': 60,
      });

      expect(
        model.endTime.difference(model.startTime),
        const Duration(hours: 1),
      );
    });

    test('uses the lounge timezone for the session instant', () {
      final model = ActiveSessionModel.fromJson({
        'id': 'cairo',
        'date': '2026-10-21',
        'start_time': '15:00:00',
        'end_time': '16:00:00',
        'lounges': {'timezone': 'Africa/Cairo'},
      });

      expect(model.startTime.toUtc(), DateTime.utc(2026, 10, 21, 12));
      expect(model.endTime.toUtc(), DateTime.utc(2026, 10, 21, 13));
    });

    test('hasStarted should return true when now is past startTime', () {
      final model = ActiveSessionModel.fromJson(testJson);

      expect(model.hasStarted, isTrue);
      expect(model.isUpcoming, isFalse);
    });

    test('isExpiringSoon should return true when <= 15 mins remaining', () {
      final expiringEndTime = DateTime.now().add(const Duration(minutes: 10));
      final expiringModel = ActiveSessionModel(
        bookingId: '1',
        loungeId: '1',
        loungeName: 'Lounge',
        roomName: 'Room',
        deviceName: 'Device',
        startTime: DateTime.now().subtract(const Duration(minutes: 50)),
        endTime: expiringEndTime,
        basePrice: 100,
        status: 'in_progress',
      );

      expect(expiringModel.isExpiringSoon, isTrue);
    });

    test('copyWith should produce new model with updated values', () {
      final model = ActiveSessionModel.fromJson(testJson);
      final updatedModel = model.copyWith(
        status: 'completed',
        extensionsPrice: 100.0,
      );

      expect(updatedModel.status, 'completed');
      expect(updatedModel.extensionsPrice, 100.0);
      expect(updatedModel.bookingId, model.bookingId);
    });
  });
}
