import 'package:firebase_messaging/firebase_messaging.dart';

class RemoteNotificationContent {
  final int id;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  const RemoteNotificationContent({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
  });

  factory RemoteNotificationContent.fromMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final identifier =
        message.messageId ??
        data['id']?.toString() ??
        data['notification_id']?.toString();

    return RemoteNotificationContent(
      id:
          identifier?.hashCode.toUnsigned(31) ??
          DateTime.now().millisecondsSinceEpoch.toUnsigned(31),
      title: _firstNonEmpty([
        message.notification?.title,
        data['title'],
        data['notification_title'],
      ]),
      body: _firstNonEmpty([
        message.notification?.body,
        data['body'],
        data['message'],
        data['content'],
      ]),
      data: data,
    );
  }

  bool get hasVisibleContent => title != null || body != null;

  static String? _firstNonEmpty(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
