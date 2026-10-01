import 'dart:async';

class SerializedTaskQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() task) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await task());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }
}
