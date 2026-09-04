import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
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

        double hourlyRate = 50.0;
        if (session != null && session.basePrice > 0) {
          final totalMinutes = session.endTime.difference(session.startTime).inMinutes;
          if (totalMinutes > 0) {
            hourlyRate = (session.basePrice / (totalMinutes / 60.0));
          }
        }

        final cost30 = (hourlyRate * 0.5).roundToDouble();
        final cost60 = hourlyRate.roundToDouble();
        final cost120 = (hourlyRate * 2.0).roundToDouble();

        final isPending = session?.isExtensionPending ?? false;
        final isRejected = session?.isExtensionRejected ?? false;
        final pendingMins = session?.requestedExtensionMinutes ?? 30;

        if (isPending) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.withOpacity(AppColors.warning, 0.1),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.withOpacity(AppColors.warning, 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.withOpacity(AppColors.warning, 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.withOpacity(AppColors.warning, 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
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
              color: AppColors.withOpacity(AppColors.danger, 0.1),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.withOpacity(AppColors.danger, 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.withOpacity(AppColors.danger, 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.withOpacity(AppColors.danger, 0.15),
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
                  label: AppStrings.min30.tr(),
                  mins: 30,
                  cost: cost30 > 0 ? cost30 : 25.0,
                  isLoading: isLoading,
                ),
                SizedBox(width: 10.w),
                ActionCard(
                  label: AppStrings.hr1.tr(),
                  mins: 60,
                  cost: cost60 > 0 ? cost60 : 45.0,
                  isLoading: isLoading,
                ),
                SizedBox(width: 10.w),
                ActionCard(
                  label: AppStrings.hr2.tr(),
                  mins: 120,
                  cost: cost120 > 0 ? cost120 : 80.0,
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
