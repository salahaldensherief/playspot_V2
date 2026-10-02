import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/models/geo_coordinates.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';

String pointHex(Endian endian, {int srid = 4326, bool hasSrid = true}) {
  final data = ByteData(hasSrid ? 25 : 21);
  data.setUint8(0, endian == Endian.little ? 1 : 0);
  data.setUint32(1, hasSrid ? 0x20000001 : 1, endian);
  if (hasSrid) data.setUint32(5, srid, endian);
  final offset = hasSrid ? 9 : 5;
  data.setFloat64(offset, 31.2357, endian);
  data.setFloat64(offset + 8, 30.0444, endian);
  return data.buffer
      .asUint8List()
      .map((e) => e.toRadixString(16).padLeft(2, '0'))
      .join();
}

void main() {
  for (final endian in [Endian.little, Endian.big]) {
    for (final hasSrid in [true, false]) {
      test('PostGIS point $endian srid=$hasSrid preserves lat/lng order', () {
        final point = GeoCoordinates.fromSpatial(
          pointHex(endian, hasSrid: hasSrid),
        );
        expect(point?.latitude, 30.0444);
        expect(point?.longitude, 31.2357);
      });
    }
  }
  test(
    'hex EWKB with PostgreSQL prefix parses into booking and survives lounge cache',
    () {
      final hex = r'\x' + pointHex(Endian.little);
      final lounge = LoungeModel.fromJson({
        'id': 'l',
        'location_point': hex,
        'distance_km': 123.4,
        'address': 'Complete lounge address',
      });
      final cached = LoungeModel.fromJson(
        jsonDecode(jsonEncode(lounge.toJson())) as Map<String, dynamic>,
      );
      expect(cached.lat, 30.0444);
      expect(cached.lng, 31.2357);
      expect(cached.distance, 123.4);
      expect(cached.address, 'Complete lounge address');
      final booking = BookingModel.fromJson({
        'date': '2026-10-02',
        'lounges': {'location_point': hex},
        'latitude': 1,
        'longitude': 2,
      });
      expect(booking.lat, lounge.lat);
      expect(booking.lng, lounge.lng);
    },
  );
  test('partial sources cannot produce mixed coordinate pairs', () {
    final json = {'latitude': 30, 'lng': 31};
    expect(GeoCoordinates.fromJson(json), isNull);
    final booking = BookingModel.fromJson({
      'date': '2026-10-02',
      'lounges': {'latitude': 30},
      'longitude': 31,
    });
    expect(booking.lat, isNull);
    expect(booking.lng, isNull);
  });
  test('GeoJSON and WKT use longitude before latitude', () {
    for (final source in <Object>[
      {
        'type': 'Point',
        'coordinates': [31.2357, 30.0444],
      },
      'POINT(31.2357 30.0444)',
      'SRID=4326;POINT(31.2357 30.0444)',
    ]) {
      final point = GeoCoordinates.fromSpatial(source);
      expect(point?.latitude, 30.0444);
      expect(point?.longitude, 31.2357);
    }
  });
  test('string flat values, zero and negative coordinates remain valid', () {
    final point = GeoCoordinates.fromPair('-30.5', '0');
    expect(point?.latitude, -30.5);
    expect(point?.longitude, 0);
    expect(GeoCoordinates.fromPair(90, -180), isNotNull);
  });
  test(
    'malformed, non-point, projected and invalid coordinates are rejected',
    () {
      for (final value in <Object?>[
        null,
        'not a point',
        'POINT(31 NaN)',
        'SRID=3857;POINT(31 30)',
        pointHex(Endian.little, srid: 3857),
        pointHex(Endian.little).substring(2),
        {
          'type': 'Polygon',
          'coordinates': [31, 30],
        },
        {
          'type': 'Point',
          'coordinates': [31, 30, 20],
        },
        {
          'type': 'Point',
          'coordinates': [181, 30],
        },
      ]) {
        expect(GeoCoordinates.fromSpatial(value), isNull, reason: '$value');
      }
      expect(GeoCoordinates.fromPair(double.infinity, 0), isNull);
    },
  );
  for (final kilometers in [0.0, 0.85, 2.5, 123.4]) {
    test('distance $kilometers km keeps its unit after cache round trip', () {
      final model = LoungeModel.fromJson({'distance_km': kilometers});
      final cached = LoungeModel.fromJson(
        jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>,
      );
      expect(cached.distance, kilometers);
      final expected = kilometers >= 1
          ? '${kilometers.toStringAsFixed(1)} km'
          : '${(kilometers * 1000).round()} m';
      expect(cached.getFormattedDistance(isArabic: false), expected);
    });
  }
  test(
    'explicit meters convert once, legacy cached kilometers are never guessed',
    () {
      expect(LoungeModel.fromJson({'distance_meters': 850}).distance, 0.85);
      expect(LoungeModel.fromJson({'distance': 123.4}).distance, 123.4);
      expect(
        LoungeModel.fromJson({
          'distance_km': 123.4,
        }).getFormattedDistance(isArabic: true),
        '123.4 كم',
      );
    },
  );
  test('unknown distance remains unknown through JSON cache', () {
    for (final raw in [
      {},
      {'distance_km': null},
      {'distance_km': -1},
      {'distance_km': 'NaN'},
    ]) {
      final model = LoungeModel.fromJson(Map<String, dynamic>.from(raw));
      final cached = LoungeModel.fromJson(
        jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>,
      );
      expect(cached.getFormattedDistance(isArabic: false), isEmpty);
      expect(cached.distance.isInfinite, isTrue);
    }
  });
}
