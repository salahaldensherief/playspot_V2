import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_state_view.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'profile_cubit.dart';
import 'profile_state.dart';

class PointsHistoryScreen extends StatelessWidget {
  const PointsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(RouterKeys.home);
            }
          },
        ),
        title: AppText(
          text: AppStrings.pointsHistory.tr(),
          fontSize: 20.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          _buildBalanceHeader(),
          Expanded(
            child: BlocBuilder<ProfileCubit, ProfileState>(
              buildWhen: (previous, current) =>
                  previous.pointsHistory != current.pointsHistory ||
                  previous.status != current.status,
              builder: (context, state) {
                if (state.status == ProfileStatus.loading && state.pointsHistory.isEmpty) {
                  return const AppLoader(size: 40);
                }

                if (state.pointsHistory.isEmpty) {
                  return AppStateView.empty(
                    title: context.locale.languageCode == 'ar'
                        ? "لا يوجد سجل معاملة نقاط حتى الآن"
                        : "No points transactions found yet",
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.all(20.w),
                  itemCount: state.pointsHistory.length + 1,
                  separatorBuilder: (context, index) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    if (index == state.pointsHistory.length) {
                      return const SafeBottomSpacer();
                    }
                    final item = state.pointsHistory[index];
                    return _buildTransactionCard(context, item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHeader() {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (previous, current) => previous.pointsBalance != current.pointsBalance,
      builder: (context, state) {
        return Container(
          width: double.infinity,
          margin: EdgeInsets.all(20.w),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            children: [
              AppText(
                text: AppStrings.yourBalance.tr(),
                color: Colors.white70,
                fontSize: 14.sp,
              ),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars, color: Colors.white, size: 28.sp),
                  SizedBox(width: 8.w),
                  AppText(
                    text: state.pointsBalance.toString(),
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(BuildContext context, Map<String, dynamic> item) {
    final points = (item['points'] as num?)?.toInt() ?? 0;
    final isPositive = points >= 0;
    final isArabic = context.locale.languageCode == 'ar';

    final type = (item['type'] ?? item['transaction_type'] ?? '').toString();
    final description = _getTransactionTitle(type, item['description']?.toString(), isArabic);
    final createdAtStr = item['created_at']?.toString();

    DateTime? createdAt;
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      createdAt = DateTime.tryParse(createdAtStr);
    }

    return GlassContainer(
      borderRadius: 16.r,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: (isPositive ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: isPositive ? AppColors.success : AppColors.danger,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: description,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  if (createdAt != null) ...[
                    SizedBox(height: 4.h),
                    AppText(
                      text: DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            AppText(
              text: "${isPositive ? '+' : ''}$points",
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isPositive ? AppColors.success : AppColors.danger,
            ),
          ],
        ),
      ),
    );
  }

  String _getTransactionTitle(String type, String? rawDescription, bool isArabic) {
    if (rawDescription != null && rawDescription.trim().isNotEmpty) {
      return rawDescription;
    }

    switch (type.toLowerCase()) {
      case 'booking_completed':
      case 'booking':
        return isArabic ? 'حجز مكتمل' : 'Completed Booking';
      case 'first_booking':
        return isArabic ? 'مكافأة أول حجز' : 'First Booking Bonus';
      case 'review':
        return isArabic ? 'تقييم صالة' : 'Venue Review';
      case 'referral':
        return isArabic ? 'دعوة صديق' : 'Referral Bonus';
      case 'redemption':
        return isArabic ? 'استبدال نقاط' : 'Points Redeemed';
      case 'admin_adjust':
        return isArabic ? 'تعديل إداري' : 'Admin Adjustment';
      case 'refund':
      case 'booking_reversal':
        return isArabic ? 'عكس نقاط حجز' : 'Booking Points Reversal';
      default:
        return isArabic ? 'معاملة نقاط' : 'Points Transaction';
    }
  }
}
