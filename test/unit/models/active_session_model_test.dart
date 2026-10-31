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

    test(
      'Open Time uses the server start instant and never expires locally',
      () {
        final started = DateTime.now().subtract(const Duration(hours: 2));
        final model = ActiveSessionModel.fromJson({
          'id': 'open',
          'is_open_time': true,
          'status': 'in_progress',
          'date': '2026-10-21',
          'start_time': '12:00:00',
          'end_time': '12:00:00',
          'open_time_started_at': started.toUtc().toIso8601String(),
          'open_time_pricing_snapshot': {
            'effective_hourly_rate': 75,
            'minimum_minutes': 30,
            'rounding_minutes': 15,
          },
        });

        expect(model.isOpenTime, isTrue);
        expect(model.startTime.toUtc(), started.toUtc());
        expect(model.isExpiringSoon, isFalse);
        expect(model.isOvertime, isFalse);
        expect(model.openTimePricingSnapshot['effective_hourly_rate'], 75);
        expect(ActiveSessionModel.fromEntity(model).isOpenTime, isTrue);
        expect(model.copyWith(status: 'completed').isOpenTime, isTrue);
      },
    );

    test(
      'Open Time completed session parses open_time_ended_at accurately',
      () {
        final started = DateTime.utc(2026, 10, 22, 14, 0, 0);
        final ended = DateTime.utc(2026, 10, 22, 15, 45, 0);

        final payload = <String, dynamic>{
          'id': 'open_done',
          'is_open_time': true,
          'status': 'completed',
          'open_time_started_at': started.toIso8601String(),
          'open_time_ended_at': ended.toIso8601String(),
          'base_price': 87.5,
        };
        final model = ActiveSessionModel.fromJson(payload);
        final restoredAfterRestart = ActiveSessionModel.fromJson(payload);

        expect(model.isOpenTime, isTrue);
        expect(model.status, 'completed');
        expect(model.openTimeEndedAt, isNotNull);
        expect(model.totalPlayDurationMinutes, 105);
        expect(model.formattedPlayDuration, '1 h 45 m');
        expect(restoredAfterRestart.totalPlayDurationMinutes, 105);
        expect(restoredAfterRestart.formattedPlayDuration, '1 h 45 m');
      },
    );

    test(
      'Open Time completed session falls back to open_time_closed_at if ended_at absent',
      () {
        final started = DateTime.utc(2026, 10, 22, 14, 0, 0);
        final closed = DateTime.utc(2026, 10, 22, 15, 30, 0);

        final model = ActiveSessionModel.fromJson({
          'id': 'open_closed',
          'is_open_time': true,
          'status': 'completed',
          'open_time_started_at': started.toIso8601String(),
          'open_time_closed_at': closed.toIso8601String(),
          'base_price': 75.0,
        });

        expect(model.totalPlayDurationMinutes, 90);
        expect(model.formattedPlayDuration, '1 h 30 m');
      },
    );

    test(
      'Open Time completed session falls back to duration_minutes if timestamps absent',
      () {
        final started = DateTime.utc(2026, 10, 22, 14, 0, 0);

        final model = ActiveSessionModel.fromJson({
          'id': 'open_duration',
          'is_open_time': true,
          'status': 'completed',
          'open_time_started_at': started.toIso8601String(),
          'duration_minutes': 75,
          'base_price': 62.5,
        });

        expect(model.totalPlayDurationMinutes, 75);
        expect(model.formattedPlayDuration, '1 h 15 m');
      },
    );

    test(
      'Open Time completion never invents duration from generic end_time',
      () {
        final model = ActiveSessionModel.fromJson({
          'id': 'open_missing_authoritative_end',
          'is_open_time': true,
          'status': 'completed',
          'date': '2026-10-22',
          'start_time': '14:00:00',
          'end_time': '14:30:00',
          'open_time_started_at': '2026-10-22T14:00:00Z',
          'base_price': 0.0,
        });

        expect(model.openTimeEndedAt, isNull);
        expect(model.totalPlayDurationMinutes, 0);
        expect(model.formattedPlayDuration, '0 m');
      },
    );

    test('Open Time completed session handles midnight crossing correctly', () {
      final started = DateTime.utc(2026, 10, 22, 23, 30, 0);
      final ended = DateTime.utc(2026, 10, 23, 1, 15, 0);

      final model = ActiveSessionModel.fromJson({
        'id': 'open_midnight',
        'is_open_time': true,
        'status': 'completed',
        'open_time_started_at': started.toIso8601String(),
        'open_time_ended_at': ended.toIso8601String(),
        'base_price': 100.0,
      });

      expect(model.totalPlayDurationMinutes, 105);
      expect(model.formattedPlayDuration, '1 h 45 m');
    });

    test('excludes cancelled orders from roomBasePrice fallback clamp', () {
      final model = ActiveSessionModel.fromJson({
        'id': 'with_canteen',
        'status': 'in_progress',
        'total_price': 150.0,
        'canteen_orders': [
          {
            'status': 'delivered',
            'items': [
              {'name': 'Burger', 'price': 50.0, 'quantity': 1},
            ],
          },
          {
            'status': 'cancelled',
            'items': [
              {'name': 'Shisha', 'price': 40.0, 'quantity': 1},
            ],
          },
        ],
      });

      // Valid orders = 50. Cancelled orders (40) excluded.
      // Base room price clamp = 150 - 50 = 100.
      expect(model.orders.length, 2);
      expect(model.ordersTotal, 50.0);
      expect(model.basePrice, 100.0);
      expect(model.grandTotal, 150.0);
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
