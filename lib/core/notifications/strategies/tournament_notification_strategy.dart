import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'notification_action_strategy.dart';

class TournamentNotificationStrategy implements NotificationActionStrategy {
  const TournamentNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase() ?? '';
    final tournamentId = data['tournament_id'] ?? data['tournamentId'];
    return type.contains('tournament') || tournamentId != null;
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    final tournamentId = data['tournament_id']?.toString() ?? data['tournamentId']?.toString();
    if (tournamentId != null && tournamentId.isNotEmpty) {
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
