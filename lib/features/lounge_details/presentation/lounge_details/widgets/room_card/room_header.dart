import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'room_theme_extension.dart';

class RoomHeader extends StatelessWidget {
  final RoomModel room;
  final bool isArabic;
  final bool isAvailable;
  final bool isExpanded;
  final Color themeColor;

  const RoomHeader({
    super.key,
    required this.room,
    required this.isArabic,
    required this.isAvailable,
    required this.isExpanded,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(room.icon, color: themeColor, size: 20.sp),
        10.horizontalSpace,
        Expanded(
          child: AppText(
            text: room.getDisplayTitle(isArabic),
            fontSize: 14.sp,
            fontWeight: FontWeight.w900,
            color: isAvailable ? Colors.white : AppColors.textSecondary,
            maxLines: isExpanded ? 5 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(
          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: themeColor.withOpacity(0.4),
          size: 18.sp,
        ),
      ],
    );
  }
}
