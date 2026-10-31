import 'package:playspot/core/services/directions_url_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

class RecordingDirectionsLauncher implements DirectionsUrlLauncher {
  final List<Object> outcomes;
  final List<Uri> urls = [];
  final List<LaunchMode> modes = [];
  RecordingDirectionsLauncher(this.outcomes);

  @override
  Future<bool> launch(Uri uri, LaunchMode mode) async {
    urls.add(uri);
    modes.add(mode);
    final outcome = outcomes.removeAt(0);
    if (outcome is Exception) throw outcome;
    return outcome as bool;
  }
}
