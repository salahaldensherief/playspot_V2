import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/layout/app_divider.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../home/data/models/lounge_model.dart';

class LoungeInfoSection extends StatelessWidget {
  final LoungeModel lounge;

  const LoungeInfoSection({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.star,
                      color: index < 4
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      size: 20.sp,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                AppText(
                  text: "${lounge.rating} · 124 ${AppStrings.reviews.tr()}",
                  fontSize: 14.sp,
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            AppText(
              text: AppStrings.seeReviews.tr(),
              fontSize: 14.sp,
              color: AppColors.neonBlue,
              fontWeight: FontWeight.bold,
            ),
            const AppDivider(),
          ],
        ),
      ),
    );
  }
}
