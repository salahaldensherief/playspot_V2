import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/services/directions_service_impl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../support/recording_directions_launcher.dart';

void main() {
  test(
    'destination is coordinates, without search or stale cached origin',
    () async {
      final launcher = RecordingDirectionsLauncher([true]);
      expect(
        await DirectionsServiceImpl(
          launcher: launcher,
        ).openDirections(lat: 30.0444, lng: 31.2357),
        isTrue,
      );
      final url = launcher.urls.single;
      expect(url.scheme, 'https');
      expect(url.host, 'www.google.com');
      expect(url.path, '/maps/dir/');
      expect(url.queryParameters, {
        'api': '1',
        'destination': '30.0444,31.2357',
        'dir_action': 'navigate',
      });
      expect(launcher.modes, [LaunchMode.externalApplication]);
    },
  );

  for (final failure in [false, Exception('no handler')]) {
    test(
      'browser fallback preserves the exact destination after $failure',
      () async {
        final launcher = RecordingDirectionsLauncher([failure, true]);
        expect(
          await DirectionsServiceImpl(
            launcher: launcher,
          ).openDirections(lat: -33.9, lng: 0),
          isTrue,
        );
        expect(launcher.urls.length, 2);
        expect(launcher.urls[0], launcher.urls[1]);
        expect(launcher.urls.last.queryParameters['destination'], '-33.9,0.0');
        expect(launcher.modes.last, LaunchMode.platformDefault);
      },
    );
  }

  test('both rejected handlers report failure', () async {
    final launcher = RecordingDirectionsLauncher([false, false]);
    expect(
      await DirectionsServiceImpl(
        launcher: launcher,
      ).openDirections(lat: 0, lng: 0),
      isFalse,
    );
    expect(launcher.urls.length, 2);
  });

  for (final pair in <List<double?>>[
    [null, 31],
    [30, null],
    [91, 31],
    [30, -181],
    [double.nan, 0],
    [0, double.infinity],
  ]) {
    test('invalid coordinate pair $pair never opens a name search', () async {
      final launcher = RecordingDirectionsLauncher([]);
      expect(
        await DirectionsServiceImpl(
          launcher: launcher,
        ).openDirections(lat: pair[0], lng: pair[1]),
        isFalse,
      );
      expect(launcher.urls, isEmpty);
    });
  }
}
