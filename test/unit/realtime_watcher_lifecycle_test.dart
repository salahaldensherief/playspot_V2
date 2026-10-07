import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/mixins/realtime_watcher_mixin.dart';

class Watcher with RealtimeWatcherMixin {}

void main() {
  test('cancellation during retry delay prevents resubscription', () async {
    final source = StreamController<int>();
    var calls = 0;
    final subscription = Watcher().subscribeWithRetry<int>(
      streamFactory: () { calls++; return source.stream; },
      onData: (_) {}, onError: (_) {}, retryDelay: const Duration(milliseconds: 10),
    );
    source.addError(Exception('network disconnected'));
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 1);
    expect(source.hasListener, isFalse);
    unawaited(source.close());
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('returned subscription cancels the replacement stream after retry', () async {
    final first = StreamController<int>();
    final second = StreamController<int>();
    var calls = 0;
    final values = <int>[];
    final subscription = Watcher().subscribeWithRetry<int>(
      streamFactory: () => calls++ == 0 ? first.stream : second.stream,
      onData: values.add, onError: (_) {}, retryDelay: const Duration(milliseconds: 10),
    );
    first.addError(Exception('network disconnected'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 2);
    second.add(1);
    await Future<void>.delayed(Duration.zero);
    expect(values, [1]);
    await subscription.cancel();
    expect(second.hasListener, isFalse);
    second.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(values, [1]);
    unawaited(first.close());
    unawaited(second.close());
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('permission failures do not start a retry loop', () async {
    final source = StreamController<int>();
    var calls = 0;
    final subscription = Watcher().subscribeWithRetry<int>(
      streamFactory: () { calls++; return source.stream; },
      onData: (_) {}, onError: (_) {}, retryDelay: const Duration(milliseconds: 10),
    );
    source.addError(Exception('42501 row-level security denied'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 1);
    await subscription.cancel();
    expect(source.hasListener, isFalse);
    unawaited(source.close());
  }, timeout: const Timeout(Duration(seconds: 30)));
}
