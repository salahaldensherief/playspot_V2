import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/theme/app_sizes.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../home/data/models/lounge_model.dart';

class LoungeInfoSection extends StatelessWidget {
  final LoungeModel lounge;

  const LoungeInfoSection({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
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
                      color: index < lounge.rating.floor()
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      size: 18.sp,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                AppText(
                  text: "${lounge.rating} · ${lounge.totalReviews ?? 0} ${AppStrings.reviews.tr()}",
                  fontSize: 13.sp,
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
            if (lounge.getDescription(isArabic) != null) ...[
              SizedBox(height: 8.h),
              AppText(
                text: lounge.getDescription(isArabic)!,
                fontSize: 13.sp,
                color: AppColors.textSecondary,
                height: 1.5,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                showAllTextOnTap: true,
              ),
            ],
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }
}
