import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/rating/rating_display_widget.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/lounge_details/data/models/review_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';

class ReviewsSection extends StatelessWidget {
  final List<ReviewModel>? reviews;
  final bool isLimitApplied;

  const ReviewsSection({
    super.key,
    this.reviews,
    this.isLimitApplied = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reviews != null) {
      return reviews!.isEmpty ? _buildEmptyState() : _buildList(context, reviews!, limit: isLimitApplied);
    }
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (previous, current) => previous.reviews != current.reviews,
      builder: (context, state) {
        if (state.reviews.isEmpty) return _buildEmptyState();
        return _buildList(context, state.reviews, limit: true);
      },
    );
  }

  Widget _buildEmptyState() {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Column(
            children: [
              Icon(Icons.star_outline_rounded, color: AppColors.textSecondary, size: 36.sp),
              SizedBox(height: 8.h),
              AppText(
                text: AppStrings.noReviewsYet.tr(),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ReviewModel> reviewsList, {bool limit = false}) {
    final double avgRating = reviewsList.isNotEmpty
        ? (reviewsList.fold(0.0, (sum, item) => sum + item.rating) / reviewsList.length)
        : 0.0;

    final bool shouldLimit = limit && reviewsList.length > 2;
    final int displayCount = shouldLimit ? 4 : (reviewsList.length + 1);

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return _buildRatingSummaryHeader(context, avgRating, reviewsList.length);
            }

            final reviewIndex = index - 1;
            final review = reviewsList[reviewIndex];

            // If we are at index 3 (the 3rd comment) and limiting, apply the gradient shadow fade
            if (shouldLimit && index == 3) {
              return _buildFadedReviewCard(context, review, reviewsList.length);
            }

            return _buildReviewCard(review);
          },
          childCount: displayCount,
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: GlassContainer(
        borderRadius: 16,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16.r,
                    backgroundImage: review.userAvatar != null && review.userAvatar!.isNotEmpty
                        ? CachedNetworkImageProvider(review.userAvatar!)
                        : null,
                    child: review.userAvatar == null || review.userAvatar!.isEmpty
                        ? const Icon(Icons.person, size: 16, color: AppColors.white)
                        : null,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          text: review.userName,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        SizedBox(height: 2.h),
                        RatingDisplayWidget(
                          rating: review.rating,
                          starSize: 12.sp,
                          spacing: 2.w,
                        ),
                      ],
                    ),
                  ),
                  AppText(
                    text: DateFormat('dd/MM/yyyy').format(review.createdAt),
                    fontSize: 10.sp,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                SizedBox(height: 8.h),
                AppText(
                  text: review.comment!,
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFadedReviewCard(BuildContext context, ReviewModel review, int totalCount) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Stack(
        children: [
          _buildReviewCard(review),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.scaffoldBackground.withValues(alpha: 0.1),
                    AppColors.scaffoldBackground.withValues(alpha: 0.85),
                    AppColors.scaffoldBackground,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 16.h),
                  child: AppButton(
                    content: ButtonContent(
                      label: "${AppStrings.seeReviews.tr()} ($totalCount)",
                    ),
                    buttonConfig: ButtonConfig(
                      backgroundColor: AppColors.cardBackground,
                      borderColor: AppColors.neonBlue,
                      borderRadius: 12.r,
                      width: 200.w,
                      height: 42.h,
                      textStyle: TextStyle(
                        color: AppColors.neonBlue,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    behavior: ButtonBehavior.tap(
                      isEnabled: true,
                      onTap: () {
                        final cubit = context.read<LoungeDetailsCubit>();
                        final loungeName = cubit.state.lounge?.name ?? "";
                        context.pushNamed(
                          RouterKeys.allReviews,
                          extra: {
                            'reviews': cubit.state.reviews,
                            'loungeName': loungeName,
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummaryHeader(BuildContext context, double avgRating, int totalCount) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h, top: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.withOpacity(AppColors.warning, 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.withOpacity(AppColors.warning, 0.12),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.withOpacity(AppColors.warning, 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  text: avgRating.toStringAsFixed(1),
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
                SizedBox(height: 2.h),
                RatingDisplayWidget(
                  rating: avgRating,
                  starSize: 10.sp,
                  spacing: 2.w,
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: AppStrings.reviews.tr(),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
                SizedBox(height: 4.h),
                AppText(
                  text: AppStrings.basedOnUserReviews.tr(args: [totalCount.toString()]),
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
