import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/widgets/rating/rating_display_widget.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

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
            BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
              buildWhen: (previous, current) => previous.reviews != current.reviews,
              builder: (context, state) {
                final int reviewCount = state.reviews.isNotEmpty
                    ? state.reviews.length
                    : (lounge.totalReviews ?? 0);
                final double displayRating = (state.reviews.isNotEmpty)
                    ? (state.reviews.fold(0.0, (sum, item) => sum + item.rating) / state.reviews.length)
                    : lounge.rating;

                return Row(
                  children: [
                    RatingDisplayWidget(
                      rating: displayRating,
                      starSize: 18.sp,
                      spacing: 2.w,
                    ),
                    SizedBox(width: 8.w),
                    AppText(
                      text: "${displayRating > 0 ? displayRating.toStringAsFixed(1) : "N/A"} · $reviewCount ${AppStrings.reviews.tr()}",
                      fontSize: 13.sp,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                );
              },
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
