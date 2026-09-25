import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'notification_action_strategy.dart';

class OfferNotificationStrategy implements NotificationActionStrategy {
  const OfferNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase() ?? '';
    return type.contains('offer') || type.contains('promo') || type.contains('voucher');
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    context.pushNamed(RouterKeys.myVouchers);

    final promoCode = _extractPromoCode(data);
    if (promoCode.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: promoCode));
      final isArabic = context.locale.languageCode == 'ar';
      GameHudToast.show(
        context,
        isArabic ? "تم نسخ كود الخصم: $promoCode" : "Promo code copied: $promoCode",
        type: ToastType.success,
      );
    }
    return true;
  }

  String _extractPromoCode(Map<String, dynamic> data) {
    final possibleKeys = ['promo_code', 'code', 'promoCode', 'coupon'];
    for (final key in possibleKeys) {
      final val = data[key]?.toString().trim();
      if (val != null && val.isNotEmpty && val != 'null') {
        return val;
      }
    }
    final textFallback = "${data['body'] ?? ''} ${data['title'] ?? ''}";
    final codeMatch = RegExp(r'[A-Z0-9]{5,10}').firstMatch(textFallback);
    return codeMatch?.group(0) ?? '';
  }
}
