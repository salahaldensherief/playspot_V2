import 'dart:typed_data';
import 'dart:math' as math;
import 'package:equatable/equatable.dart';

class GeoCoordinates extends Equatable {
  final double latitude;
  final double longitude;
  const GeoCoordinates._(this.latitude, this.longitude);

  double distanceInKilometersTo(GeoCoordinates other) {
    final latitudeDelta = (other.latitude - latitude) * math.pi / 180;
    final longitudeDelta = (other.longitude - longitude) * math.pi / 180;
    final haversine =
        (math.pow(math.sin(latitudeDelta / 2), 2) +
                math.cos(latitude * math.pi / 180) *
                    math.cos(other.latitude * math.pi / 180) *
                    math.pow(math.sin(longitudeDelta / 2), 2))
            .clamp(0.0, 1.0);
    return 6378.137 * 2 * math.asin(math.sqrt(haversine));
  }

  static GeoCoordinates? fromPair(Object? latitude, Object? longitude) {
    final lat = _number(latitude);
    final lng = _number(longitude);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return GeoCoordinates._(lat, lng);
  }

  static double? _number(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }

  static GeoCoordinates? fromJson(Map<String, dynamic> json) =>
      fromPair(json['latitude'], json['longitude']) ??
      fromPair(json['lat'], json['lng']) ??
      fromSpatial(json['location_point']);

  static GeoCoordinates? fromSpatial(Object? value) {
    if (value is Map && value['type'] == 'Point') {
      final coordinates = value['coordinates'];
      if (coordinates is List && coordinates.length == 2) {
        return fromPair(coordinates[1], coordinates[0]);
      }
      return null;
    }
    if (value is! String) return null;
    final text = value.trim();
    // WGS84 examples: POINT(31.2 30.0), SRID=4326;POINT(31.2 30.0).
    final point = RegExp(
      r'^(?:SRID=4326;)?POINT\s*\(\s*([^\s]+)\s+([^\s]+)\s*\)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (point != null) return fromPair(point.group(2), point.group(1));
    return _fromBinary(text);
  }

  static GeoCoordinates? _fromBinary(String text) {
    final hex = text.startsWith(r'\x') ? text.substring(2) : text;
    if (![42, 50].contains(hex.length) ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      return null;
    }
    final bytes = Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
    if (bytes[0] != 0 && bytes[0] != 1) return null;
    final endian = bytes[0] == 1 ? Endian.little : Endian.big;
    final data = ByteData.sublistView(bytes);
    final type = data.getUint32(1, endian);
    if (type != 1 && type != 0x20000001) return null;
    final hasSrid = type == 0x20000001;
    if (bytes.length != (hasSrid ? 25 : 21)) return null;
    if (hasSrid && data.getUint32(5, endian) != 4326) return null;
    final offset = hasSrid ? 9 : 5;
    return fromPair(
      data.getFloat64(offset + 8, endian),
      data.getFloat64(offset, endian),
    );
  }

  @override
  List<Object> get props => [latitude, longitude];
}
