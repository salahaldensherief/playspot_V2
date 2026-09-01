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
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: AppText(
        text: room.spaceTypeLabel(isArabic),
        fontSize: 7.sp,
        fontWeight: FontWeight.w900,
        color: themeColor,
        letterSpacing: 0.3,
      ),
    );
  }
}
