import 'dart:async';
import 'dart:developer' as dev;

/// A mixin providing standardized stream subscription management with automatic retry logic for Realtime streams.
mixin RealtimeWatcherMixin {
  /// Checks if a stream error is related to authentication or permission issues.
  bool isAuthError(dynamic error) {
    final errStr = error.toString().toLowerCase();
    return errStr.contains('42501') ||
        errStr.contains('row-level security') ||
        errStr.contains('permission denied') ||
        errStr.contains('unauthorized') ||
        errStr.contains('jwt expired') ||
        errStr.contains('not authenticated');
  }

  /// Subscribes to a stream with auto-retry upon non-auth errors after a specified [retryDelay].
  StreamSubscription<T> subscribeWithRetry<T>({
    required Stream<T> Function() streamFactory,
    required void Function(T data) onData,
    void Function(dynamic error)? onError,
    bool Function()? isClosedCheck,
    Duration retryDelay = const Duration(seconds: 3),
    String tag = 'RealtimeWatcherMixin',
  }) {
    StreamSubscription<T>? active;
    Timer? retryTimer;
    bool cancelled = false;
    late StreamController<T> output;
    late void Function() startListening;
    void handleError(Object error, StackTrace stack) {
      if (cancelled || output.isClosed) return;
      dev.log('[$tag] STREAM ERROR: $error');
      output.addError(error, stack);
      unawaited(active?.cancel());
      active = null;
      if (isAuthError(error)) {
        unawaited(output.close());
        return;
      }
      retryTimer?.cancel();
      retryTimer = Timer(retryDelay, () {
        if (!cancelled && !(isClosedCheck?.call() ?? false)) startListening();
      });
    }
    startListening = () {
      if (cancelled || (isClosedCheck?.call() ?? false)) return;
      try {
        active = streamFactory().listen(
          output.add,
          onError: handleError,
          onDone: () => unawaited(output.close()),
        );
        if (output.isPaused) active?.pause();
      } catch (error, stack) {
        handleError(error, stack);
      }
    };
    output = StreamController<T>(
      onListen: () => startListening(),
      onPause: () => active?.pause(),
      onResume: () => active?.resume(),
      onCancel: () async {
        cancelled = true;
        retryTimer?.cancel();
        await active?.cancel();
        active = null;
      },
    );
    return output.stream.listen(onData, onError: onError);
  }
}
