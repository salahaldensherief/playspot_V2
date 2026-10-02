import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/models/geo_coordinates.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/home/domain/usecases/recalculate_lounge_distances_usecase.dart';

void main() {
  const calculate = RecalculateLoungeDistancesUseCase();
  test(
    'offline spherical estimate matches the verified Cairo PostGIS example within 20 meters',
    () {
      final origin = GeoCoordinates.fromPair(30.0444, 31.2357)!;
      final destination = GeoCoordinates.fromPair(30.0131, 31.2156)!;
      expect(
        origin.distanceInKilometersTo(destination),
        closeTo(3.97464437794, 0.02),
      );
      expect(
        destination.distanceInKilometersTo(origin),
        origin.distanceInKilometersTo(destination),
      );
      expect(origin.distanceInKilometersTo(origin), 0);
      expect(
        GeoCoordinates.fromPair(
          0,
          0,
        )!.distanceInKilometersTo(GeoCoordinates.fromPair(0, 180)!),
        closeTo(20037.508, 0.01),
      );
    },
  );
  test(
    'offline estimates sort by distance and preserve real venue comparison data through cache',
    () {
      final far = LoungeModel.fromJson({
        'id': 'far',
        'latitude': 30.02,
        'longitude': 31,
        'distance_km': 1,
        'rating': 4.9,
      });
      final near = LoungeModel.fromJson({
        'id': 'near',
        'latitude': 30,
        'longitude': 31,
        'distance_km': 9,
        'address': 'Complete address',
        'price_per_hour': 100,
        'has_discount': true,
        'discount_percentage': 20,
        'discount_expires_at': '2099-01-01T00:00:00Z',
        'images': ['https://example.com/photo.jpg'],
        'wallet_number': 'fixture',
      });
      final values = calculate(
        [far, near],
        GeoCoordinates.fromPair(30, 31),
        sortByDistance: true,
      );
      expect(values.map((value) => value.id), ['near', 'far']);
      expect(values.first.distance, 0);
      final cached = LoungeModel.fromJson(
        jsonDecode(jsonEncode(values.first.toJson())) as Map<String, dynamic>,
      );
      expect(cached.distanceIsApproximate, true);
      expect(cached.address, near.address);
      expect(cached.pricePerHour, 100);
      expect(cached.images, near.images);
      expect(cached.walletNumber, near.walletNumber);
      expect(cached.isDiscountActive, true);
      expect(cached.discountPercentage, 20);
      expect(
        calculate(
          [near, far],
          GeoCoordinates.fromPair(30, 31),
          sortByDistance: false,
        ).first.id,
        'far',
      );
    },
  );
  test(
    'missing origins or destinations never keep unrelated cached distances',
    () {
      final venue = LoungeModel.fromJson({
        'id': 'with',
        'latitude': 30,
        'longitude': 31,
        'distance_km': 12,
      });
      final missing = LoungeModel.fromJson({'id': 'missing', 'distance_km': 2});
      expect(
        calculate(
          [venue],
          null,
          sortByDistance: true,
        ).single.distance.isInfinite,
        true,
      );
      final values = calculate(
        [missing, venue],
        GeoCoordinates.fromPair(30, 31),
        sortByDistance: true,
      );
      expect(values.first.id, 'with');
      expect(values.last.distance.isInfinite, true);
      expect(values.last.getFormattedDistance(isArabic: true), isEmpty);
    },
  );
  test('measure local distance recalculation for 100 cached lounges', () {
    final lounges = List.generate(
      100,
      (i) => LoungeModel.fromJson({
        'id': '$i',
        'latitude': 30 + i * 0.001,
        'longitude': 31,
      }),
    );
    final watch = Stopwatch()..start();
    final values = calculate(
      lounges,
      GeoCoordinates.fromPair(30, 31),
      sortByDistance: true,
    );
    watch.stop();
    expect(values.length, 100);
    expect(values.first.id, '0');
    expect(values.last.distanceIsApproximate, true);
    final path = Platform.environment['PLAYSPOT_SCREENSHOT_DIR'];
    if (path != null) {
      File('$path/offline-distance-measurement.json').writeAsStringSync(
        jsonEncode({
          'mode':
              'Flutter unit test/debug on Windows; synthetic venues; not device frame timings',
          'lounges': 100,
          'elapsedMicroseconds': watch.elapsedMicroseconds,
        }),
      );
    }
  });
}
