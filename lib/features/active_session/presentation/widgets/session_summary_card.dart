import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/active_session/data/models/active_session_model.dart';

import 'billing_breakdown.dart';

class SessionSummaryCard extends StatelessWidget {
  final ActiveSessionModel session;
  final VoidCallback onRateExperience;

  const SessionSummaryCard({
    super.key,
    required this.session,
    required this.onRateExperience,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Column(
        children: [
          // Completed Graphic & Header
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.sports_esports_rounded,
              color: AppColors.success,
              size: 54.sp,
            ),
          ),
          SizedBox(height: 16.h),
          AppText(
            text: AppStrings.sessionEndedTitle.tr(),
            fontSize: 22.sp,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          AppText(
            text: AppStrings.sessionEndedSubtitle.tr(),
            fontSize: 13.5.sp,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 24.h),

          // Lounge & Station Details Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.divider, width: 1.0),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      text: AppStrings.sessionDetails.tr(),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neonBlue,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: AppText(
                        text: 'مكتملة',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                const Divider(color: AppColors.divider, height: 1),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 18.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    AppText(
                      text: session.loungeName.isNotEmpty
                          ? session.loungeName
                          : 'PlaySpot Lounge',
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.videogame_asset_rounded,
                      size: 18.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    AppText(
                      text: '${session.roomName} • ${session.deviceName}',
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_filled_rounded,
                      size: 18.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    AppText(
                      text: '${AppStrings.totalPlayTime.tr()}: ',
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                    AppText(
                      text: session.formattedPlayDuration,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neonBlue,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Billing Breakdown
          BillingBreakdownWidget(session: session),

          SizedBox(height: 24.h),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: AppButton(
                  content: ButtonContent(
                    label: AppStrings.rateExperience.tr(),
                    icon: const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                  behavior: ButtonBehavior.tap(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onRateExperience();
                    },
                  ),
                  buttonConfig: ButtonConfig(
                    height: 48.h,
                    backgroundColor: AppColors.neonPurple,
                    borderRadius: 14.r,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppButton(
                  content: ButtonContent(label: AppStrings.backToHome.tr()),
                  behavior: ButtonBehavior.tap(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.goNamed(RouterKeys.home);
                    },
                  ),
                  buttonConfig: ButtonConfig(
                    height: 48.h,
                    backgroundColor: Colors.transparent,
                    borderColor: AppColors.textSecondary,
                    isOutlined: true,
                    borderRadius: 14.r,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
