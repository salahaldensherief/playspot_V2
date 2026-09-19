import 'dart:async';
import 'dart:developer' as dev;

/// A mixin providing standardized stream subscription management with automatic retry logic for Realtime streams.
mixin RealtimeWatcherMixin {
  /// Checks if a stream error is related to authentication or permission issues.
  bool isAuthError(dynamic error) {
    final errStr = error.toString().toLowerCase();
    return errStr.contains('permission denied') ||
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
    late StreamSubscription<T> subscription;

    void startListening() {
      subscription = streamFactory().listen(
        onData,
        onError: (err) {
          dev.log("[$tag] STREAM ERROR: $err");
          onError?.call(err);
          subscription.cancel();

          if (!isAuthError(err)) {
            Future.delayed(retryDelay, () {
              final closed = isClosedCheck?.call() ?? false;
              if (!closed) {
                dev.log("[$tag] Retrying stream subscription after error...");
                startListening();
              }
            });
          }
        },
      );
    }

    startListening();
    return subscription;
  }
}
