import 'package:url_launcher/url_launcher.dart';
import '../models/geo_coordinates.dart';
import 'directions_service.dart';
import 'directions_url_launcher.dart';
import 'platform_directions_url_launcher.dart';

class DirectionsServiceImpl implements DirectionsService {
  final DirectionsUrlLauncher launcher;
  const DirectionsServiceImpl({
    this.launcher = const PlatformDirectionsUrlLauncher(),
  });

  @override
  Future<bool> openDirections({
    required double? lat,
    required double? lng,
  }) async {
    final point = GeoCoordinates.fromPair(lat, lng);
    if (point == null) return false;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${point.latitude},${point.longitude}',
      'dir_action': 'navigate',
    });
    for (final mode in [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        if (await launcher.launch(uri, mode)) return true;
      } catch (_) {}
    }
    return false;
  }
}
