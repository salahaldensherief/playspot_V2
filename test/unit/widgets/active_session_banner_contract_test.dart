import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home session banner uses one pausable localized ticker', () {
    final source = File(
      'lib/features/home/presentation/widgets/active_session_banner.dart',
    ).readAsStringSync();

    expect(RegExp(r'Timer\.periodic').allMatches(source), hasLength(1));
    expect(source, contains('TickerMode.valuesOf(context).enabled'));
    expect(source, contains('AppStrings.activeSession.tr()'));
    expect(source, contains('AppStrings.joinNow.tr()'));
    expect(source, contains('AppStrings.sessionTimeRemaining.tr'));
    expect(source, isNot(contains("text: 'Live now'")));
    expect(source, isNot(contains("text: 'Join'")));
    expect(source, isNot(contains("timeText = 'Session ended'")));
  });
}
