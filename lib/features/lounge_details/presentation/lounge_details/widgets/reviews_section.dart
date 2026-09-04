import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/rating/rating_display_widget.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/features/lounge_details/data/models/review_model.dart';
import '../lounge_details_cubit.dart';
import '../lounge_details_state.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReviewsSection extends StatelessWidget {
  final List<ReviewModel>? reviews;
  const ReviewsSection({super.key, this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews != null) {
      return _buildList(context, reviews!);
    }
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (previous, current) => previous.reviews != current.reviews,
      builder: (context, state) {
        if (state.reviews.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return _buildList(context, state.reviews);
      },
    );
  }

  Widget _buildList(BuildContext context, List<ReviewModel> reviewsList) {
    final double avgRating = reviewsList.isNotEmpty
        ? (reviewsList.fold(0.0, (sum, item) => sum + item.rating) / reviewsList.length)
        : 0.0;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return _buildRatingSummaryHeader(context, avgRating, reviewsList.length);
            }
            final review = reviewsList[index - 1];
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
          },
          childCount: reviewsList.length + 1,
        ),
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
