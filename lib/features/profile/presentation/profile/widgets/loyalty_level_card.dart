import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../profile_cubit.dart';
import '../profile_state.dart';

class LoyaltyLevelCard extends StatelessWidget {
  const LoyaltyLevelCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (previous, current) =>
          previous.pointsBalance != current.pointsBalance ||
          previous.loyaltyStatus != current.loyaltyStatus,
      builder: (context, state) {
        final status = state.loyaltyStatus;
        final points = state.pointsBalance;
        final currentLevel = status?.currentLevel ?? 'Bronze';
        final nextPoints = status?.nextLevelPoints ?? 100;
        final multiplier = status?.multiplier ?? 1.0;

        final levelColor = _getLevelColor(currentLevel);
        final levelIcon = _getLevelIcon(currentLevel);
        final progressRatio = status?.progressRatio ??
            (nextPoints > 0 ? (points / nextPoints).clamp(0.0, 1.0) : 1.0);
        final remainingPoints = status?.pointsRemaining ??
            (nextPoints > points ? (nextPoints - points) : 0);

        return Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(vertical: 12.h),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                levelColor.withValues(alpha: 0.3),
                AppColors.cardBackground,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: levelColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Level Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: levelColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(levelIcon, color: levelColor, size: 16.sp),
                        SizedBox(width: 6.w),
                        AppText(
                          text: currentLevel,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ],
                    ),
                  ),

                  // Multiplier Badge
                  if (multiplier > 1.0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(TablerIcons.bolt, color: AppColors.warning, size: 14.sp),
                          SizedBox(width: 4.w),
                          AppText(
                            text: "${multiplier}x ${AppStrings.multiplier.tr()}",
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16.h),

              // Points Count Big Display
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Icon(Icons.stars, color: levelColor, size: 30.sp),
                  SizedBox(width: 8.w),
                  AppText(
                    text: points.toString(),
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  SizedBox(width: 6.w),
                  AppText(
                    text: AppStrings.points.tr(),
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Next Level Progress & Percentage
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppText(
                        text: AppStrings.nextLevelPoints.tr(),
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                      AppText(
                        text: "${(progressRatio * 100).toInt()}%",
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: levelColor,
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      minHeight: 8.h,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (remainingPoints > 0)
                    AppText(
                      text: AppStrings.pointsRemaining.tr(args: [remainingPoints.toString()]),
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getLevelColor(String level) {
    final lower = level.toLowerCase();
    if (lower.contains('gold') || lower.contains('ذهبي')) {
      return const Color(0xFFFFD700);
    } else if (lower.contains('silver') || lower.contains('فضي')) {
      return const Color(0xFFC0C0C0);
    } else if (lower.contains('platinum') || lower.contains('بلاتيني')) {
      return const Color(0xFFE5E4E2);
    } else if (lower.contains('diamond') || lower.contains('ماسي')) {
      return const Color(0xFF00FFFF);
    }
    return const Color(0xFFCD7F32); // Bronze
  }

  IconData _getLevelIcon(String level) {
    final lower = level.toLowerCase();
    if (lower.contains('gold') || lower.contains('ذهبي')) {
      return TablerIcons.crown;
    } else if (lower.contains('diamond') || lower.contains('ماسي')) {
      return TablerIcons.diamond;
    }
    return TablerIcons.award;
  }
}
