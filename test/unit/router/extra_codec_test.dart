import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

void main() {
  group('MyExtraCodec tests', () {
    const codec = MyExtraCodec();

    const lounge = LoungeModel(
      id: 'lounge_1',
      name: 'Test Lounge',
      imageUrl: 'http://example.com/img.png',
      rating: 4.8,
      distance: 2.5,
      pricePerHour: 100.0,
      isOpen: true,
      openingTime: '10:00',
      closingTime: '23:00',
    );

    const room = RoomModel(
      id: 'room_1',
      loungeId: 'lounge_1',
      nameAr: 'غرفة VIP',
      nameEn: 'VIP Room',
      activityNames: ['PlayStation 5'],
      maxCapacity: 4,
      hourlyRateSingle: 100.0,
      hourlyRateMulti: 150.0,
      isAvailable: true,
      images: [],
      featuresAr: [],
      featuresEn: [],
    );

    test('BookingDetailsParams encode & decode', () {
      final params = BookingDetailsParams(
        lounge: lounge,
        room: room,
        selectedDate: DateTime(2025, 5, 1, 14, 0),
        extras: const [
          {'id': 'ext_1', 'name': 'Extra Drink', 'price': 15.0}
        ],
        playMode: 'multi',
        extraControllers: 2,
      );

      final encoded = codec.encoder.convert(params);
      expect(encoded, isNotNull);

      final decoded = codec.decoder.convert(encoded);
      expect(decoded, isA<BookingDetailsParams>());

      final decodedParams = decoded as BookingDetailsParams;
      expect(decodedParams.lounge.id, 'lounge_1');
      expect(decodedParams.room.id, 'room_1');
      expect(decodedParams.playMode, 'multi');
      expect(decodedParams.extraControllers, 2);
    });

    test('CheckoutParams encode & decode', () {
      final params = CheckoutParams(
        lounge: lounge,
        room: room,
        date: DateTime(2025, 5, 1),
        startTime: const TimeOfDay(hour: 15, minute: 30),
        duration: 2,
        totalPrice: 200.0,
        originalTotalPrice: 220.0,
        addOns: const [
          {'name': 'Snack', 'price': 20.0}
        ],
        playMode: 'single',
        extraControllers: 1,
      );

      final encoded = codec.encoder.convert(params);
      expect(encoded, isNotNull);

      final decoded = codec.decoder.convert(encoded);
      expect(decoded, isA<CheckoutParams>());

      final decodedParams = decoded as CheckoutParams;
      expect(decodedParams.lounge.name, 'Test Lounge');
      expect(decodedParams.room.nameEn, 'VIP Room');
      expect(decodedParams.startTime.hour, 15);
      expect(decodedParams.startTime.minute, 30);
      expect(decodedParams.totalPrice, 200.0);
    });
  });
}
