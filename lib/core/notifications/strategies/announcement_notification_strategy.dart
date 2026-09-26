import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/features/app_status/presentation/widgets/announcement_dialog.dart';
import 'notification_action_strategy.dart';

class AnnouncementNotificationStrategy implements NotificationActionStrategy {
  const AnnouncementNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    final type = NotificationStrategyHelper.cleanString(data['type'])?.toLowerCase() ?? '';
    final hasAnnouncementKeys = data.containsKey('announcement_id') ||
        data.containsKey('announcement_title');
    if (!type.contains('announcement') && !hasAnnouncementKeys) return false;

    final title = NotificationStrategyHelper.extractFirst(
      data,
      const ['announcement_title', 'title', 'heading'],
    );
    final body = NotificationStrategyHelper.extractFirst(
      data,
      const ['announcement_body', 'body', 'message'],
    );
    return title != null || body != null;
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    if (!NotificationStrategyHelper.isAuthenticated()) {
      context.goNamed(RouterKeys.signIn);
      return true;
    }

    final title = NotificationStrategyHelper.extractFirst(
      data,
      const ['announcement_title', 'title', 'heading'],
    );
    final body = NotificationStrategyHelper.extractFirst(
      data,
      const ['announcement_body', 'body', 'message'],
    );
    final imageUrl = NotificationStrategyHelper.extractFirst(
      data,
      const ['announcement_image_url', 'image_url', 'image'],
    );
    final actionUrl = NotificationStrategyHelper.extractFirst(
      data,
      const ['announcement_action_url', 'action_url', 'url'],
    );

    AnnouncementDialog.show(
      context,
      title: title ?? '',
      body: body ?? '',
      imageUrl: imageUrl,
      actionUrl: actionUrl,
    );
    return true;
  }
}
