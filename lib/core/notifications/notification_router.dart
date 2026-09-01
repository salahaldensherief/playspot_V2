typedef NotificationNavigationHandler =
    bool Function(Map<String, dynamic> data);

class NotificationRouter {
  NotificationRouter._();

  static NotificationNavigationHandler? _handler;

  static Map<String, dynamic>? _pendingData;

  static void configure(NotificationNavigationHandler handler) {
    _handler = handler;
    handlePending();
  }

  static void navigate(Map<String, dynamic> data) {
    final handler = _handler;

    if (handler == null || !handler(data)) {
      _pendingData = data;
      return;
    }

    _pendingData = null;
  }

  static void handlePending() {
    final pendingData = _pendingData;
    final handler = _handler;
    if (pendingData == null || handler == null || !handler(pendingData)) return;

    _pendingData = null;
  }
}
