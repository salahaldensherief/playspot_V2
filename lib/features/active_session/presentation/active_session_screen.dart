import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../../../../core/di.dart';
import '../data/models/active_session_model.dart';
import 'active_session_cubit.dart';
import 'active_session_state.dart';
import 'widgets/timer_widget.dart';
import 'widgets/billing_breakdown.dart';
import 'widgets/menu_bottom_sheet.dart';

class ActiveSessionScreen extends StatelessWidget {
  const ActiveSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<ActiveSessionCubit>()..loadActiveSession(),
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            text: "activeSession".tr(),
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: BlocConsumer<ActiveSessionCubit, ActiveSessionState>(
          listenWhen: (prev, curr) => 
              prev.extendStatus != curr.extendStatus || 
              prev.orderStatus != curr.orderStatus,
          listener: (context, state) {
            if (state.extendStatus == ActionStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Session extended successfully".tr()), backgroundColor: AppColors.success),
              );
            }
            if (state.orderStatus == ActionStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Order placed successfully".tr()), backgroundColor: AppColors.success),
              );
            }
            if (state.errorMessage != null && (state.extendStatus == ActionStatus.error || state.orderStatus == ActionStatus.error)) {
               ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.danger),
              );
            }
          },
          builder: (context, state) {
             if (state.status == ActiveSessionStatus.loading && state.session == null) {
              return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue));
            }
            if (state.status == ActiveSessionStatus.empty) {
              return Center(child: AppText(text: "noUpcomingBookings".tr()));
            }
            if (state.status == ActiveSessionStatus.error && state.session == null) {
              return Center(child: AppText(text: state.errorMessage ?? "somethingWentWrong".tr()));
            }

            final session = state.session!;
            final totalDuration = session.endTime.difference(session.startTime);
            final progress = totalDuration.inSeconds > 0 
                ? state.remainingTime.inSeconds / totalDuration.inSeconds 
                : 0.0;
            
            Color statusColor = AppColors.success;
            if (session.isOvertime) {
              statusColor = AppColors.danger;
            } else if (session.isExpiringSoon) {
              statusColor = AppColors.warning;
            }

            return RefreshIndicator(
              onRefresh: () => context.read<ActiveSessionCubit>().loadActiveSession(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(20.w),
                child: Column(
                  children: [
                    TimerWidget(
                      remaining: state.remainingTime,
                      progress: progress.clamp(0.0, 1.0),
                      statusColor: statusColor,
                    ),
                    SizedBox(height: 32.h),
                    _buildStationInfo(session),
                    SizedBox(height: 24.h),
                    _buildQuickActions(context, state),
                    SizedBox(height: 24.h),
                    BillingBreakdownWidget(session: session),
                    SizedBox(height: 32.h),
                    AppButton(
                      content: ButtonContent(
                        label: "orderExtras".tr(),
                        icon: Icon(Icons.fastfood_rounded, color: AppColors.white, size: 20.sp),
                      ),
                      buttonConfig: ButtonConfig(
                        width: double.infinity,
                        backgroundColor: AppColors.neonPurple,
                        glowColor: AppColors.neonPurple,
                      ),
                      behavior: TapBehavior(
                        isEnabled: true,
                        onTap: () => _showMenuBottomSheet(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStationInfo(ActiveSessionModel session) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.videogame_asset_rounded, color: AppColors.neonBlue, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: session.loungeName,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: 4.h),
                AppText(
                  text: "${session.roomName} - ${session.deviceName}",
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                text: "station".tr(),
                fontSize: 10.sp,
                color: AppColors.textSecondary,
              ),
              AppText(
                text: "#${session.bookingId.substring(0, 6).toUpperCase()}",
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.neonBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ActiveSessionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          text: "extendTime".tr(),
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
        ),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionCard(context, "min30".tr(), 30, 25.0, state.extendStatus == ActionStatus.loading),
            _buildActionCard(context, "hr1".tr(), 60, 45.0, state.extendStatus == ActionStatus.loading),
            _buildActionCard(context, "hr2".tr(), 120, 80.0, state.extendStatus == ActionStatus.loading),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String label, int mins, double cost, bool isLoading) {
    return InkWell(
      onTap: isLoading ? null : () => context.read<ActiveSessionCubit>().extendTime(mins, cost),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 105.w,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          children: [
            AppText(text: label, fontWeight: FontWeight.bold, fontSize: 14.sp),
            SizedBox(height: 4.h),
            AppText(
              text: "${cost.toInt()} ${"egp".tr()}",
              fontSize: 12.sp,
              color: AppColors.neonBlue,
            ),
          ],
        ),
      ),
    );
  }

  void _showMenuBottomSheet(BuildContext context) {
    final cubit = context.read<ActiveSessionCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: cubit,
        child: const MenuBottomSheet(),
      ),
    );
  }
}
