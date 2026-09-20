import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/layout/app_loader.dart';
import '../../../../art_core/widgets/layout/app_refresh_indicator.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'active_session_action_bar.dart';
import 'billing_breakdown.dart';
import 'lounge_review_bottom_sheet.dart';
import 'quick_actions.dart';
import 'session_summary_card.dart';
import 'station_info.dart';
import 'timer_section.dart';

class ActiveSessionBody extends StatelessWidget {
  const ActiveSessionBody({super.key});

  void _showReviewBottomSheet(BuildContext context, dynamic session) {
    final cubit = context.read<ActiveSessionCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LoungeReviewBottomSheet(
        loungeName: session.loungeName,
        onSubmit: (rating, comment) =>
            cubit.submitReview(rating: rating, comment: comment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveSessionCubit, ActiveSessionState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.session != curr.session ||
          prev.completedSession != curr.completedSession ||
          prev.errorMessage != curr.errorMessage,
      builder: (context, state) {
        if (state.status == ActiveSessionStatus.loading ||
            state.status == ActiveSessionStatus.initial) {
          return const AppLoader(size: 40);
        }

        if (state.status == ActiveSessionStatus.error) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                    size: 48.sp,
                  ),
                  SizedBox(height: 16.h),
                  AppText(
                    text:
                        state.errorMessage ??
                        AppStrings.somethingWentWrong.tr(),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  AppButton(
                    content: ButtonContent(label: AppStrings.retry.tr()),
                    behavior: ButtonBehavior.tap(
                      onTap: () => context
                          .read<ActiveSessionCubit>()
                          .loadActiveSession(),
                    ),
                    buttonConfig: ButtonConfig(
                      height: 44.h,
                      width: 120.w,
                      backgroundColor: AppColors.neonBlue,
                      borderRadius: 12.r,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.status == ActiveSessionStatus.empty &&
            state.completedSession != null) {
          return SessionSummaryCard(
            session: state.completedSession!,
            onRateExperience: () =>
                _showReviewBottomSheet(context, state.completedSession!),
          );
        }

        if (state.status == ActiveSessionStatus.empty ||
            state.session == null) {
          return AppRefreshIndicator(
            onRefresh: () =>
                context.read<ActiveSessionCubit>().loadActiveSession(),
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
                        color: AppColors.neonBlue.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.neonBlue.withValues(alpha: 0.2),
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

        return AppRefreshIndicator(
          onRefresh: () =>
              context.read<ActiveSessionCubit>().loadActiveSession(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                const TimerSection(),
                SizedBox(height: 20.h),
                _buildPendingExtensionBanner(context, session),
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

  Widget _buildPendingExtensionBanner(BuildContext context, dynamic session) {
    final status = session.extensionStatus?.toString().toLowerCase();
    final mins = session.requestedExtensionMinutes ?? 0;

    if (status != 'pending' && mins <= 0) {
      return const SizedBox.shrink();
    }

    final isArabic = context.locale.languageCode == 'ar';
    final displayMins = mins > 0 ? mins : 30;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: isArabic ? "طلب التمديد قيد المراجعة ⏳" : "Extension Request Pending ⏳",
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
                SizedBox(height: 3.h),
                AppText(
                  text: isArabic
                      ? "تم إرسال طلب تمديد الجلسة (+$displayMins دقيقة) لكاشير الصالة وجاري اعتماده الآن."
                      : "Session extension request (+$displayMins mins) sent to lounge staff and is being processed.",
                  fontSize: 11.5.sp,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
