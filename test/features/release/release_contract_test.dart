import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release safety contracts', () {
    test('mobile uses canonical staff assistance and canteen RPCs', () {
      final source = File(
        'lib/features/booking/data/datasources/remote/'
        'booking_remote_data_source.dart',
      ).readAsStringSync();

      expect(source, contains("'request_staff_assistance_for_booking'"));
      expect(source, contains("'place_canteen_order'"));
      expect(source, isNot(contains("'call_staff_request'")));
      expect(source, isNot(contains(".from('service_calls').insert")));
    });

    test('removed slot waitlist backend is never referenced', () {
      final dartSources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(dartSources, isNot(contains("'join_slot_waitlist'")));
      expect(dartSources, isNot(contains("'join_room_waitlist'")));
      expect(dartSources, isNot(contains("from('slot_waitlist')")));
    });

    test('release signing fails closed unless CI explicitly opts in', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('releaseTaskRequested'));
      expect(gradle, contains('allowDebugReleaseSigning'));
      expect(gradle, contains('throw GradleException'));
    });
  });
}
