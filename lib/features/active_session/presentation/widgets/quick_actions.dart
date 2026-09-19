import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'action_card.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (prev, curr) =>
          prev.extendStatus != curr.extendStatus || prev.session != curr.session,
      builder: (context, state) {
        final isLoading = state.extendStatus == ActionStatus.loading;
        final session = state.session;
        final cubit = context.read<ActiveSessionCubit>();

        final cost15 = cubit.calculateExtensionCost(15);
        final cost30 = cubit.calculateExtensionCost(30);
        final cost60 = cubit.calculateExtensionCost(60);

        final isPending = session?.isExtensionPending ?? false;
        final isRejected = session?.isExtensionRejected ?? false;
        final pendingMins = session?.requestedExtensionMinutes ?? 30;

        if (isPending) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.warning.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const AppLoader(
                      size: 20,
                      strokeWidth: 2.5,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText(
                        text: AppStrings.extensionPendingTitle.tr(),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                      SizedBox(height: 4.h),
                      AppText(
                        text: AppStrings.extensionPendingSubtitle.tr(args: [pendingMins.toString()]),
                        fontSize: 12.5.sp,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (isRejected) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cancel_rounded,
                    color: AppColors.danger,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText(
                        text: AppStrings.extensionDeclinedTitle.tr(),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                      SizedBox(height: 4.h),
                      AppText(
                        text: AppStrings.extensionDeclinedSubtitle.tr(),
                        fontSize: 12.5.sp,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_alarm_rounded,
                  color: AppColors.neonBlue,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                AppText(
                  text: AppStrings.extendTime.tr(),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                ActionCard(
                  label: AppStrings.min15.tr(),
                  mins: 15,
                  cost: cost15 > 0 ? cost15 : 15.0,
                  isLoading: isLoading,
                ),
                SizedBox(width: 8.w),
                ActionCard(
                  label: AppStrings.min30.tr(),
                  mins: 30,
                  cost: cost30 > 0 ? cost30 : 25.0,
                  isLoading: isLoading,
                ),
                SizedBox(width: 8.w),
                ActionCard(
                  label: AppStrings.hr1.tr(),
                  mins: 60,
                  cost: cost60 > 0 ? cost60 : 50.0,
                  isLoading: isLoading,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
