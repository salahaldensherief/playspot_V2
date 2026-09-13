import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:playspot/core/cache/preference_manager.dart';

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

  factory RemoteNotificationContent.fromMessage(RemoteMessage message, [String? lang]) {
    final data = Map<String, dynamic>.from(message.data);
    final identifier =
        message.messageId ??
        data['id']?.toString() ??
        data['notification_id']?.toString();

    final titleAr = data['title_ar']?.toString();
    final titleEn = data['title_en']?.toString();
    final bodyAr = data['body_ar']?.toString();
    final bodyEn = data['body_en']?.toString();

    final currentLang = (lang ?? PreferenceManager().currentLang()).toLowerCase().trim();

    String? resolvedTitle;
    if (currentLang == 'ar') {
      resolvedTitle = _firstNonEmpty([
        titleAr,
        data['title'],
        data['notification_title'],
        message.notification?.title,
        titleEn,
      ]);
    } else {
      resolvedTitle = _firstNonEmpty([
        titleEn,
        data['title'],
        data['notification_title'],
        message.notification?.title,
        titleAr,
      ]);
    }

    String? resolvedBody;
    if (currentLang == 'ar') {
      resolvedBody = _firstNonEmpty([
        bodyAr,
        data['body'],
        data['message'],
        data['content'],
        message.notification?.body,
        bodyEn,
      ]);
    } else {
      resolvedBody = _firstNonEmpty([
        bodyEn,
        data['body'],
        data['message'],
        data['content'],
        message.notification?.body,
        bodyAr,
      ]);
    }

    return RemoteNotificationContent(
      id: identifier?.hashCode.toUnsigned(31) ??
          DateTime.now().millisecondsSinceEpoch.toUnsigned(31),
      title: resolvedTitle,
      body: resolvedBody,
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
