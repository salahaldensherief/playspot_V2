import 'package:url_launcher/url_launcher.dart';

abstract class DirectionsUrlLauncher {
  Future<bool> launch(Uri uri, LaunchMode mode);
}
