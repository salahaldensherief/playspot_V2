import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_dialog.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/shimmer/redemption_option_shimmer.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/features/profile/data/models/redemption_option_model.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';
import 'profile_cubit.dart';
import 'profile_state.dart';

class RedeemPointsScreen extends StatelessWidget {
  const RedeemPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == ProfileStatus.redeemSuccess) {
          // Success Dialog with Voucher Code
          final lastVoucher = state.myVouchers.isNotEmpty ? state.myVouchers.last : null;
          final code = lastVoucher?['code'] ?? "";
          
          AppDialog.show(
            context,
            type: AppDialogType.success,
            title: AppStrings.rewardRedeemed.tr(),
            description: "🎉 تم! عندك كوبون جديد بكود $code، صالح لمدة 30 يوم",
            confirmText: AppStrings.continueText.tr(),
          );
        } else if (state.status == ProfileStatus.error && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: Text(
            AppStrings.redeemPoints.tr(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Column(
          children: [
            _buildBalanceHeader(),
            Expanded(
              child: BlocBuilder<ProfileCubit, ProfileState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status ||
                    previous.redemptionOptions != current.redemptionOptions ||
                    previous.pointsBalance != current.pointsBalance,
                builder: (context, state) {
                  if (state.status == ProfileStatus.loading) {
                    return ListView.builder(
                      padding: EdgeInsets.all(20.w),
                      itemCount: 5,
                      itemBuilder: (context, index) => const RedemptionOptionShimmer(),
                    );
                  }

                  if (state.redemptionOptions.isEmpty) {
                    return Center(
                      child: AppText(text: AppStrings.noRewardsAvailable.tr(), color: Colors.white),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.all(20.w),
                    itemCount: state.redemptionOptions.length + 1,
                    separatorBuilder: (context, index) => SizedBox(height: 16.h),
                    itemBuilder: (context, index) {
                      if (index == state.redemptionOptions.length) {
                        return const SafeBottomSpacer();
                      }
                      final option = state.redemptionOptions[index];
                      return _buildRedemptionCard(context, option, state.pointsBalance, isArabic);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedemptionCard(
    BuildContext context,
    RedemptionOptionModel option,
    int currentBalance,
    bool isArabic,
  ) {
    final canAfford = currentBalance >= option.pointsCost;
    final rewardIcon = option.rewardType == 'free_hour' 
        ? Icons.timer_outlined 
        : Icons.confirmation_number_outlined;

    return GlassContainer(
      borderRadius: 24.r,
      child: Stack(
        children: [
          // Background Gradient Overlay for Points
          Positioned(
            top: 0,
            right: isArabic ? null : 0,
            left: isArabic ? 0 : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(isArabic ? 0 : 20.r),
                  bottomRight: Radius.circular(isArabic ? 20.r : 0),
                  topRight: Radius.circular(isArabic ? 0 : 24.r),
                  topLeft: Radius.circular(isArabic ? 24.r : 0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars_rounded, color: AppColors.warning, size: 14.sp),
                  SizedBox(width: 4.w),
                  AppText(
                    text: "${option.pointsCost}",
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.neonBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.neonBlue.withOpacity(0.2)),
                      ),
                      child: Icon(rewardIcon, color: AppColors.neonBlue, size: 24.sp),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            text: option.getTitle(isArabic),
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          SizedBox(height: 2.h),
                          AppText(
                            text: option.rewardType == 'free_hour' 
                                ? "1 Hour Session" 
                                : "${option.rewardValue.toInt()} EGP Discount",
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neonBlue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                AppText(
                  text: option.getDescription(isArabic),
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                SizedBox(height: 20.h),
                AppButton(
                  buttonConfig: ButtonConfig(
                    height: 48.h,
                    gradient: canAfford ? AppColors.primaryGradient : null,
                  ),
                  content: ButtonContent(
                    label: AppStrings.redeem.tr(),
                  ),
                  behavior: ButtonBehavior.tap(
                    isEnabled: canAfford,
                    onTap: () => context.read<ProfileCubit>().redeemPoints(option.id),
                  ),
                ),
              ],
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
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Column(
            children: [
              AppText(
                text: AppStrings.yourBalance.tr(),
                color: Colors.white70,
                fontSize: 16,
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars, color: Colors.white, size: 32.sp),
                  SizedBox(width: 8.w),
                  AppText(
                    text: state.pointsBalance.toString(),
                    fontSize: 36.sp,
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
}
