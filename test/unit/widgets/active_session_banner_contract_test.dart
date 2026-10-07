import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home session banner uses one pausable localized ticker', () {
    final source = File(
      'lib/features/home/presentation/widgets/active_session_banner.dart',
    ).readAsStringSync();

    expect(source, contains('AppClockBuilder('));
    expect(source, isNot(contains('Timer.periodic')));
    expect(source, contains('AppStrings.liveNow.tr()'));
    expect(source, contains('AppStrings.joinNow.tr()'));
    expect(source, contains('LocalizedDurationFormatter'));
    expect(source, isNot(contains("text: 'Live now'")));
    expect(source, isNot(contains("text: 'Join'")));
    expect(source, isNot(contains("timeText = 'Session ended'")));
  });
}
