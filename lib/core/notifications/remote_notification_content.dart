import 'package:flutter/foundation.dart';
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

    final currentLang = (lang ?? PlatformDispatcher.instance.locale.languageCode).toLowerCase().trim();

    String? resolvedTitle;
    if (currentLang == 'ar') {
      resolvedTitle = _firstNonEmpty([
        titleAr,
        message.notification?.title,
        data['title'],
        data['notification_title'],
        titleEn,
      ]);
    } else {
      resolvedTitle = _firstNonEmpty([
        titleEn,
        message.notification?.title,
        data['title'],
        data['notification_title'],
        titleAr,
      ]);
    }

    String? resolvedBody;
    if (currentLang == 'ar') {
      resolvedBody = _firstNonEmpty([
        bodyAr,
        message.notification?.body,
        data['body'],
        data['message'],
        data['content'],
        bodyEn,
      ]);
    } else {
      resolvedBody = _firstNonEmpty([
        bodyEn,
        message.notification?.body,
        data['body'],
        data['message'],
        data['content'],
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
