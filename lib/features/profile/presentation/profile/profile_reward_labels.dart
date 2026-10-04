import 'package:easy_localization/easy_localization.dart';

class ProfileRewardLabels {
  static String transaction(String type, String? description) {
    final key = switch (type.toLowerCase()) {
      'booking_completed' || 'booking' => 'booking',
      'first_booking' => 'first_booking',
      'review' => 'review',
      'referral' => 'referral',
      'redemption' => 'redemption',
      'admin_adjust' => 'admin_adjust',
      'refund' || 'booking_reversal' => 'reversal',
      _ => null,
    };
    if (key != null) return 'profile_rewards.$key'.tr();
    return description?.trim().isNotEmpty == true
        ? description!.trim()
        : 'profile_rewards.transaction'.tr();
  }

  static String level(String value) {
    final key = switch (value.toLowerCase()) {
      'bronze' || 'برونزي' => 'bronze',
      'silver' || 'فضي' => 'silver',
      'gold' || 'ذهبي' => 'gold',
      'platinum' || 'بلاتيني' => 'platinum',
      'diamond' || 'ماسي' => 'diamond',
      _ => null,
    };
    return key == null ? value : 'profile_rewards.$key'.tr();
  }

  static String date(Map<String, dynamic> voucher, String locale) {
    final used = voucher['status'] == 'used';
    final value = DateTime.tryParse(
      (used ? voucher['used_at'] : voucher['expires_at'])?.toString() ?? '',
    );
    if (value == null) return 'profile_rewards.date_unknown'.tr();
    final key = used
        ? 'used_on'
        : voucher['status'] == 'expired'
        ? 'expired_on'
        : 'valid_until';
    return 'profile_rewards.$key'.tr(
      namedArgs: {'date': DateFormat.yMMMd(locale).format(value.toLocal())},
    );
  }
}
