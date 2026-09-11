import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/profile/data/models/loyalty_mission_model.dart';
import '../profile_cubit.dart';
import '../profile_state.dart';

class LoyaltyMissionsSection extends StatelessWidget {
  const LoyaltyMissionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (previous, current) =>
          previous.loyaltyMissions != current.loyaltyMissions ||
          previous.status != current.status,
      builder: (context, state) {
        final missions = state.loyaltyMissions;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  TablerIcons.target,
                  color: AppColors.neonPurple,
                  size: 22.sp,
                ),
                SizedBox(width: 8.w),
                AppText(
                  text: AppStrings.loyaltyMissions.tr(),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ],
            ),
            SizedBox(height: 12.h),

            if (missions.isEmpty)
              _buildEmptyState(context)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: missions.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final mission = missions[index];
                  return _buildMissionCard(context, mission);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return GlassContainer(
      borderRadius: 16.r,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          color: AppColors.cardBackground.withValues(alpha: 0.5),
        ),
        child: Column(
          children: [
            Icon(
              TablerIcons.target_off,
              color: AppColors.textSecondary,
              size: 40.sp,
            ),
            SizedBox(height: 8.h),
            AppText(
              text: AppStrings.noActiveMissions.tr(),
              fontSize: 14.sp,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionCard(BuildContext context, LoyaltyMissionModel mission) {
    final progressRatio = mission.targetProgress > 0
        ? (mission.currentProgress / mission.targetProgress).clamp(0.0, 1.0)
        : (mission.isCompleted ? 1.0 : 0.0);

    final statusText = _getStatusText(mission);
    final statusColor = _getStatusColor(mission);

    return GlassContainer(
      borderRadius: 16.r,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
          ),
          color: AppColors.cardBackground.withValues(alpha: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    mission.isCompleted
                        ? TablerIcons.circle_check
                        : TablerIcons.trophy,
                    color: statusColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        text: mission.title,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      if (mission.description.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        AppText(
                          text: mission.description,
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                // Points Reward Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars, color: AppColors.warning, size: 14.sp),
                      SizedBox(width: 4.w),
                      AppText(
                        text: "+${mission.pointsReward}",
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Progress Bar & Mission Status Text
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      minHeight: 8.h,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: AppText(
                    text: "$statusText (${mission.currentProgress}/${mission.targetProgress})",
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(LoyaltyMissionModel mission) {
    if (mission.isCompleted || (mission.currentProgress >= mission.targetProgress && mission.targetProgress > 0)) {
      return AppStrings.completed.tr();
    }
    if (mission.currentProgress > 0) {
      return AppStrings.inProgress.tr();
    }
    return AppStrings.notStarted.tr();
  }

  Color _getStatusColor(LoyaltyMissionModel mission) {
    if (mission.isCompleted || (mission.currentProgress >= mission.targetProgress && mission.targetProgress > 0)) {
      return AppColors.success;
    }
    if (mission.currentProgress > 0) {
      return AppColors.neonBlue;
    }
    return AppColors.neonPurple;
  }
}
