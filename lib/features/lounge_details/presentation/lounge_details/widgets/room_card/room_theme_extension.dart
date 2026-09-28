import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

extension RoomThemeX on RoomModel {
  Color get themeColor {
    if (isVIP) return AppColors.warning;
    if (isVR) return AppColors.neonPurple;
    if (isSimulator) return AppColors.cyan;
    return AppColors.neonBlue;
  }

  IconData get icon {
    if (isSimulator) return Icons.speed;
    if (isVR) return Icons.view_in_ar;
    if (isOpenArea) return Icons.monitor;
    if (isVIP) return Icons.stars;
    return Icons.meeting_room;
  }
}
