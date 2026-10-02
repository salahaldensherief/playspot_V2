import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';

void main() {
  test(
    'range dates, room identity and payment details survive decoder decomposition',
    () {
      final booking = BookingModel.fromJson({
        'id': 'b',
        'lounge_id': 'l',
        'room_id': 'r',
        'booking_period': '["2026-10-02 10:00:00+00","2026-10-02 11:00:00+00")',
        'start_time': '11:30:00',
        'end_time': '12:30:00',
        'total_price': 100,
        'rooms': {
          'id': 'r',
          'name_en': 'PS5',
          'space_types': {'label': 'VIP', 'name': 'vip_room'},
          'controllers_count': 4,
          'screen_size': '50"',
        },
        'payments': [
          {
            'id': 'payment',
            'paid_at': '2026-10-02T09:30:00Z',
            'proof_image_url': 'https://example.com/proof.jpg',
          },
        ],
        'sender_wallet_phone': 'fixture-sender',
        'reference_number': 'fixture-reference',
        'expires_at': '2026-10-02T09:45:00Z',
      });
      expect(booking.date, DateTime.utc(2026, 10, 2, 10));
      expect(booking.startDateTime, DateTime(2026, 10, 2, 11, 30));
      expect(booking.roomId, 'r');
      expect(booking.roomName, 'PS5');
      expect(booking.spaceTypeName, 'vip_room');
      expect(booking.controllersCount, 4);
      expect(booking.screenSize, '50"');
      expect(booking.totalPrice, 100);
      expect(booking.paidAt, DateTime.utc(2026, 10, 2, 9, 30));
      expect(booking.proofImageUrl, 'https://example.com/proof.jpg');
      expect(booking.senderAccount, 'fixture-sender');
      expect(booking.transactionReference, 'fixture-reference');
      expect(booking.holdExpiresAt, DateTime.utc(2026, 10, 2, 9, 45));
    },
  );
  test(
    'booking and canteen item joins preserve quantities, prices and identities',
    () {
      final booking = BookingModel.fromJson({
        'date': '2026-10-02',
        'booking_items': [
          {'addon_id': 'a', 'title': 'Water', 'quantity': 2, 'total': 30},
        ],
        'canteen_orders': [
          {
            'canteen_order_items': [
              {
                'extra_id': 'e',
                'quantity': 3,
                'extras': {'id': 'e', 'name_en': 'Juice', 'price': 20},
              },
            ],
          },
        ],
      });
      expect(booking.canteenItems, [
        {
          'id': 'a',
          'name': 'Water',
          'quantity': 2,
          'unit_price': 15.0,
          'total_price': 30.0,
        },
        {
          'id': 'e',
          'name': 'Juice',
          'quantity': 3,
          'unit_price': 20.0,
          'total_price': 60.0,
        },
      ]);
    },
  );
}
