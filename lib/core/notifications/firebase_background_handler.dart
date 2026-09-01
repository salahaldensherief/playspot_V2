import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:playspot/firebase_options.dart';

import 'local_notification_service.dart';
import 'remote_notification_content.dart';

@pragma('vm:entry-point')
Future<void> handleFirebaseBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Already initialized or platform doesn't support it
  }

  if (message.notification != null) return;

  final content = RemoteNotificationContent.fromMessage(message);
  if (!content.hasVisibleContent) return;

  final localNotifications = LocalNotificationService.instance;
  await localNotifications.initialize(readInitialNotification: false);
  await localNotifications.showNotification(
    id: content.id,
    title: content.title,
    body: content.body,
    data: content.data,
  );
}
