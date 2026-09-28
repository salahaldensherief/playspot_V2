import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
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
    if (rooms.isEmpty) return const SizedBox.shrink();

    final isArabic = context.locale.languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        12.verticalSpace,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: rooms.map((r) {
              final hasPromo = r.hasActivePromo && r.promoDiscountValue > 0;
              final promoTag = r.getPromoTag(isArabic) ?? (isArabic ? 'خصم خاص' : 'SPECIAL OFFER');

              return Container(
                margin: EdgeInsetsDirectional.only(end: 10.w),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r12),
                  border: Border.all(
                    color: hasPromo ? AppColors.warning : AppColors.neonBlue.withValues(alpha: 0.5),
                    width: hasPromo ? 1.2 : 1.0,
                  ),
                  boxShadow: hasPromo
                      ? [
                          BoxShadow(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.meeting_room_outlined,
                      size: 16.sp,
                      color: hasPromo ? AppColors.warning : AppColors.neonBlue,
                    ),
                    8.horizontalSpace,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            AppText(
                              text: r.getDisplayTitle(isArabic),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                            if (hasPromo) ...[
                              6.horizontalSpace,
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: AppText(
                                  text: promoTag,
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (hasPromo) ...[
                          2.verticalSpace,
                          Row(
                            children: [
                              Text(
                                "${r.hourlyRateSingle.toInt()} ${AppStrings.egp.tr()}",
                                style: TextStyle(
                                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              6.horizontalSpace,
                              AppText(
                                text: "${r.effectivePriceSingle.toInt()} ${AppStrings.egp.tr()}",
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ],
                          ),
                        ],
                      ],
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
