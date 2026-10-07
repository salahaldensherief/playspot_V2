import 'package:easy_localization/easy_localization.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

class RoomSpaceTypeBadge extends StatelessWidget {
  final RoomModel room;
  final bool isArabic;
  final Color themeColor;

  const RoomSpaceTypeBadge({
    super.key,
    required this.room,
    required this.isArabic,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (room.spaceTypeName) {
      'private' => 'room_private'.tr(),
      'open_area' => AppStrings.openArea.tr(),
      'vip_room' => AppStrings.vipRoom.tr(),
      'standard_room' => AppStrings.standardRoom.tr(),
      _ => room.spaceType?.trim() ?? '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: AppText(
        text: label,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: themeColor,
        letterSpacing: 0.3,
      ),
    );
  }
}
