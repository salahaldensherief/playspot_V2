import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';

class BookingRoomsChips extends StatelessWidget {
  final List<RoomModel> rooms;

  const BookingRoomsChips({
    super.key,
    required this.rooms,
  });

  @override
  Widget build(BuildContext context) {
    if (rooms.length <= 1) return const SizedBox.shrink();

    final isArabic = context.locale.languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        12.verticalSpace,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: rooms.map((r) {
              return Container(
                margin: EdgeInsetsDirectional.only(end: 8.w),
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 8.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r12),
                  border: Border.all(
                    color: AppColors.neonBlue.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.meeting_room_outlined,
                      size: 16.sp,
                      color: AppColors.neonBlue,
                    ),
                    6.horizontalSpace,
                    AppText(
                      text: r.getDisplayTitle(isArabic),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        20.verticalSpace,
      ],
    );
  }
}
