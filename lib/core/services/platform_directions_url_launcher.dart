import 'package:url_launcher/url_launcher.dart';
import 'directions_url_launcher.dart';

class PlatformDirectionsUrlLauncher implements DirectionsUrlLauncher {
  const PlatformDirectionsUrlLauncher();
  @override
  Future<bool> launch(Uri uri, LaunchMode mode) => launchUrl(uri, mode: mode);
}
