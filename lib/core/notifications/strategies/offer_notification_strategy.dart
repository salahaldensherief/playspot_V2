import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'notification_action_strategy.dart';

class OfferNotificationStrategy implements NotificationActionStrategy {
  const OfferNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    final type = NotificationStrategyHelper.cleanString(data['type'])?.toLowerCase() ?? '';
    return type.contains('offer') || type.contains('promo') || type.contains('voucher');
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    if (!NotificationStrategyHelper.isAuthenticated()) {
      context.goNamed(RouterKeys.signIn);
      return true;
    }

    final loungeId = NotificationStrategyHelper.getLoungeId(data);
    if (loungeId != null) {
      context.pushNamed(RouterKeys.loungeDetails, extra: {'loungeId': loungeId});
    } else {
      context.pushNamed(RouterKeys.myVouchers);
    }

    final promoCode = _extractPromoCode(data);
    if (promoCode.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: promoCode));
      GameHudToast.show(
        context,
        AppStrings.promoCodeCopied.tr(args: [promoCode]),
        type: ToastType.success,
      );
    }
    return true;
  }

  /// Only copies codes sent in an explicit payload key — guessing codes out of
  /// the notification text used to copy arbitrary uppercase words.
  String _extractPromoCode(Map<String, dynamic> data) {
    const possibleKeys = ['promo_code', 'code', 'promoCode', 'coupon'];
    for (final key in possibleKeys) {
      final val = NotificationStrategyHelper.cleanString(data[key]);
      if (val != null) {
        return val;
      }
    }
    return '';
  }
}
