import 'package:geolocator/geolocator.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/models/geo_coordinates.dart';

class HomeLocationTracker {
  final PreferenceManager pref;
  GeoCoordinates? lastRequested;
  GeoCoordinates? _pendingCoordinates;
  Future<void> _writes = Future.value();
  int _saveToken = 0;
  HomeLocationTracker(this.pref);

  bool isValid(Position position) =>
      GeoCoordinates.fromPair(position.latitude, position.longitude) != null;

  GeoCoordinates? get coordinates =>
      _pendingCoordinates ??
      GeoCoordinates.fromPair(pref.latitude(), pref.longitude());

  bool hasMoved(Position position) {
    final next = GeoCoordinates.fromPair(position.latitude, position.longitude);
    final last = lastRequested;
    if (next == null) return false;
    if (last == null) return true;
    return last.distanceInKilometersTo(next) > 0.5;
  }

  Future<bool> save(Position position) async {
    final next = GeoCoordinates.fromPair(position.latitude, position.longitude);
    if (next == null) return false;
    final token = ++_saveToken;
    _pendingCoordinates = next;
    final write = _writes.then((_) async {
      await pref.saveLatitude(next.latitude);
      await pref.saveLongitude(next.longitude);
    });
    _writes = write.catchError((Object error) {});
    try {
      await write;
    } catch (_) {
      return false;
    }
    if (token != _saveToken) return false;
    _pendingCoordinates = null;
    return true;
  }

  static Stream<Position> platformPositions() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 500,
    ),
  );
}
