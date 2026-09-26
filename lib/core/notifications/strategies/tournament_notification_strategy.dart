import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'notification_action_strategy.dart';

class TournamentNotificationStrategy implements NotificationActionStrategy {
  const TournamentNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    final type = NotificationStrategyHelper.cleanString(data['type'])?.toLowerCase() ?? '';
    final tournamentId = NotificationStrategyHelper.getTournamentId(data);
    return type.contains('tournament') || tournamentId != null;
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    if (!NotificationStrategyHelper.isAuthenticated()) {
      context.goNamed(RouterKeys.signIn);
      return true;
    }

    final tournamentId = NotificationStrategyHelper.getTournamentId(data);
    if (tournamentId != null) {
      context.pushNamed(
        RouterKeys.tournamentDetails,
        pathParameters: {'id': tournamentId},
      );
    } else {
      context.pushNamed(RouterKeys.tournaments);
    }
    return true;
  }
}

