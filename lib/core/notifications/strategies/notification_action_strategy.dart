/// Abstract Strategy interface for notification navigation & actions.
/// Encapsulates routing logic for specific FCM notification payload types.
abstract class NotificationActionStrategy {
  /// Checks if this strategy can handle the provided notification data payload.
  bool canHandle(Map<String, dynamic> data);

  /// Executes navigation or action corresponding to the notification payload.
  /// Returns true if handled successfully, false otherwise.
  bool handle(Map<String, dynamic> data);
}
