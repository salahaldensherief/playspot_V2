import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'timer_section.dart';
import 'station_info.dart';
import 'quick_actions.dart';
import 'active_session_action_bar.dart';
import 'billing_breakdown.dart';

class ActiveSessionBody extends StatelessWidget {
  const ActiveSessionBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.session != curr.session ||
          prev.errorMessage != curr.errorMessage,
      builder: (context, state) {
        if (state.status == ActiveSessionStatus.loading ||
            state.status == ActiveSessionStatus.initial) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.neonBlue),
          );
        }

        if (state.status == ActiveSessionStatus.error) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 48.sp),
                  SizedBox(height: 16.h),
                  AppText(
                    text: state.errorMessage ??
                        AppStrings.somethingWentWrong.tr(),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () => context
                        .read<ActiveSessionCubit>()
                        .loadActiveSession(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonBlue),
                    child: Text(AppStrings.retry.tr()),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.status == ActiveSessionStatus.empty || state.session == null) {
          return RefreshIndicator(
            onRefresh: () => context.read<ActiveSessionCubit>().loadActiveSession(),
            color: AppColors.neonBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(minHeight: 0.7.sh),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: AppColors.withOpacity(AppColors.neonBlue, 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.withOpacity(AppColors.neonBlue, 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.sports_esports_outlined,
                        color: AppColors.neonBlue,
                        size: 64.sp,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    AppText(
                      text: AppStrings.noUpcomingBookings.tr(),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.center,
                      color: AppColors.textPrimary,
                    ),
                    SizedBox(height: 8.h),
                    AppText(
                      text: AppStrings.noActiveSessionMsg.tr(),
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final session = state.session!;

        return RefreshIndicator(
          onRefresh: () =>
              context.read<ActiveSessionCubit>().loadActiveSession(),
          color: AppColors.neonBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                const TimerSection(),
                SizedBox(height: 32.h),
                StationInfo(session: session),
                SizedBox(height: 24.h),
                const QuickActions(),
                SizedBox(height: 24.h),
                const ActiveSessionActionBar(),
                SizedBox(height: 24.h),
                BillingBreakdownWidget(session: session),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        );
      },
    );
  }
}
