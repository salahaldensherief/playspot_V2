import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/widgets/time/app_clock.dart';

void main() {
  testWidgets('nested clocks share ticks without rebuilding static content', (
    tester,
  ) async {
    var reads = 0;
    var staticBuilds = 0;
    var liveBuilds = 0;
    var hiddenBuilds = 0;
    final initial = DateTime(2026);
    DateTime clock() => initial.add(Duration(seconds: reads++));
    await tester.pumpWidget(
      MaterialApp(
        home: AppClock(
          clock: clock,
          child: Column(
            children: [
              TickerMode(
                enabled: false,
                child: AppClockBuilder(
                  builder: (_, now, child) {
                    hiddenBuilds++;
                    return const SizedBox();
                  },
                ),
              ),
              Builder(
                builder: (_) {
                  staticBuilds++;
                  return const Text('static');
                },
              ),
              AppClock(
                child: AppClockBuilder(
                  builder: (_, now, child) {
                    liveBuilds++;
                    return Text(now.toIso8601String());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final before = reads;
    final builds = liveBuilds;
    await tester.pump(const Duration(seconds: 3));
    expect(reads - before, 3);
    expect(staticBuilds, 1);
    expect(hiddenBuilds, 1);
    expect(liveBuilds, greaterThan(builds));
    await tester.pumpWidget(const SizedBox());
    final disposedReads = reads;
    await tester.pump(const Duration(seconds: 3));
    expect(reads, disposedReads);
  });

  testWidgets('hidden and background clocks stop and resume immediately', (
    tester,
  ) async {
    var reads = 0;
    final visible = ValueNotifier(true);
    DateTime clock() => DateTime(2026).add(Duration(seconds: reads++));
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
          child: AppClock(clock: clock, child: const SizedBox()),
        ),
      ),
    );
    visible.value = false;
    await tester.pump();
    final hiddenReads = reads;
    await tester.pump(const Duration(seconds: 3));
    expect(reads, hiddenReads);
    visible.value = true;
    await tester.pump();
    expect(reads, greaterThan(hiddenReads));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final pausedReads = reads;
    await tester.pump(const Duration(seconds: 3));
    expect(reads, pausedReads);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(reads, greaterThan(pausedReads));
    await tester.pumpWidget(const SizedBox());
    visible.dispose();
  });
}
