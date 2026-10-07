import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/mixins/realtime_watcher_mixin.dart';

class Watcher with RealtimeWatcherMixin {}

void main() {
  testWidgets('cancellation during retry delay prevents resubscription', (tester) async {
    final source = StreamController<int>();
    var calls = 0;
    final subscription = Watcher().subscribeWithRetry<int>(
      streamFactory: () { calls++; return source.stream; },
      onData: (_) {}, onError: (_) {}, retryDelay: const Duration(milliseconds: 10),
    );
    source.addError(Exception('network disconnected'));
    await tester.pump();
    await subscription.cancel();
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls, 1);
    await source.close();
  });

  testWidgets('returned subscription cancels the replacement stream after retry', (tester) async {
    final first = StreamController<int>();
    final second = StreamController<int>();
    var calls = 0;
    final values = <int>[];
    final subscription = Watcher().subscribeWithRetry<int>(
      streamFactory: () => calls++ == 0 ? first.stream : second.stream,
      onData: values.add, onError: (_) {}, retryDelay: const Duration(milliseconds: 10),
    );
    first.addError(Exception('network disconnected'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls, 2);
    second.add(1);
    await tester.pump();
    expect(values, [1]);
    await subscription.cancel();
    expect(second.hasListener, isFalse);
    second.add(2);
    await tester.pump();
    expect(values, [1]);
    await first.close();
    await second.close();
  });

  testWidgets('permission failures do not start a retry loop', (tester) async {
    final source = StreamController<int>();
    var calls = 0;
    final subscription = Watcher().subscribeWithRetry<int>(
      streamFactory: () { calls++; return source.stream; },
      onData: (_) {}, onError: (_) {}, retryDelay: const Duration(milliseconds: 10),
    );
    source.addError(Exception('42501 row-level security denied'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls, 1);
    await subscription.cancel();
    await source.close();
  });
}
