import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../data/models/review_model.dart';
import 'widgets/reviews_section.dart';

class AllReviewsScreen extends StatelessWidget {
  final List<ReviewModel> reviews;
  final String loungeName;

  const AllReviewsScreen({
    super.key,
    required this.reviews,
    required this.loungeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  ReviewsSection(reviews: reviews),
                  const SliverSafeBottomSpacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(TablerIcons.chevron_left, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: AppStrings.reviews.tr(),
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: "Orbitron",
                ),
                AppText(
                  text: loungeName,
                  fontSize: 12.sp,
                  color: AppColors.neonBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
