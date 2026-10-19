import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

extension RoomThemeX on RoomModel {
  Color get themeColor {
    if (isBilliards) return AppColors.success;
    if (isPingPong) return AppColors.warning;
    if (isOpenArea) return AppColors.cyan;
    if (isVIP) return AppColors.warning;
    if (isVR) return AppColors.neonPurple;
    if (isSimulator) return AppColors.cyan;
    return AppColors.neonBlue;
  }

  IconData get icon {
    if (isBilliards) return Icons.adjust;
    if (isPingPong) return Icons.sports_tennis;
    if (isSimulator) return Icons.speed;
    if (isVR) return Icons.view_in_ar;
    if (isOpenArea) return Icons.monitor;
    if (isVIP) return Icons.stars;
    return Icons.meeting_room;
  }

  bool get isBilliards => activityNames.any((activity) {
    final name = activity.toLowerCase();
    return name.contains('billiard') ||
        name.contains('pool') ||
        name.contains('بليارد');
  });

  bool get isPingPong => activityNames.any((activity) {
    final name = activity.toLowerCase();
    return name.contains('ping') ||
        name.contains('table tennis') ||
        name.contains('تنس طاولة') ||
        name.contains('بينج');
  });
}
