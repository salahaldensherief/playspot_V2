import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
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
      return _buildList(reviews!);
    }
    return BlocBuilder<LoungeDetailsCubit, LoungeDetailsState>(
      buildWhen: (previous, current) => previous.reviews != current.reviews,
      builder: (context, state) {
        if (state.reviews.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return _buildList(state.reviews);
      },
    );
  }

  Widget _buildList(List<ReviewModel> reviewsList) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final review = reviewsList[index];
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
                            backgroundImage: review.userAvatar != null
                                ? CachedNetworkImageProvider(review.userAvatar!)
                                : null,
                            child: review.userAvatar == null
                                ? const Icon(Icons.person, size: 16)
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
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      Icons.star,
                                      size: 10.sp,
                                      color: i < review.rating
                                          ? AppColors.warning
                                          : AppColors.textSecondary,
                                    ),
                                  ),
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
          childCount: reviewsList.length,
        ),
      ),
    );
  }
}
