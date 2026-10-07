import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/widgets/time/app_clock.dart';
import 'package:playspot/art_core/widgets/time/deadline_countdown.dart';

void main() {
  testWidgets(
    'an expired deadline safely notifies once after the first frame',
    (tester) async {
      var calls = 0;
      final now = DateTime(2026);
      await tester.pumpWidget(
        MaterialApp(
          home: AppClock(
            clock: () => now,
            child: StatefulBuilder(
              builder: (context, setState) {
                return DeadlineCountdown(
                  deadline: now.subtract(const Duration(seconds: 1)),
                  onExpired: () => setState(() => calls++),
                  builder: (_, remaining) => Text('${remaining.inSeconds}'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(calls, 1);
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a changed deadline is rearmed and hidden deadlines wait until shown',
    (tester) async {
      var calls = 0;
      var now = DateTime(2026);
      final deadline = ValueNotifier(now.add(const Duration(seconds: 2)));
      final visible = ValueNotifier(true);
      await tester.pumpWidget(
        MaterialApp(
          home: AppClock(
            clock: () => now,
            child: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, enabled, child) =>
                  TickerMode(enabled: enabled, child: child!),
              child: ValueListenableBuilder<DateTime>(
                valueListenable: deadline,
                builder: (_, value, child) => DeadlineCountdown(
                  deadline: value,
                  onExpired: () => calls++,
                  builder: (_, remaining) => Text('${remaining.inSeconds}'),
                ),
              ),
            ),
          ),
        ),
      );
      visible.value = false;
      await tester.pump();
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(calls, 0);
      visible.value = true;
      await tester.pump();
      expect(calls, 1);
      deadline.value = now.add(const Duration(seconds: 2));
      await tester.pump();
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
      deadline.dispose();
      visible.dispose();
    },
  );
}
