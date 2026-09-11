import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_dialog.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/auth/presentation/sign_up/signup_cubit.dart';
import 'package:playspot/features/profile/data/models/redemption_option_model.dart';
import 'package:playspot/features/profile/data/models/claim_referral_result.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/router/router_keys.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';
import 'profile_cubit.dart';
import 'profile_state.dart';
import 'widgets/loyalty_level_card.dart';
import 'widgets/loyalty_missions_section.dart';
import 'widgets/referral_card.dart';

class RedeemPointsScreen extends StatelessWidget {
  const RedeemPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == ProfileStatus.redeemSuccess) {
          final lastVoucher = state.myVouchers.isNotEmpty ? state.myVouchers.last : null;
          final code = lastVoucher?['code'] ?? "";

          AppDialog.show(
            context,
            type: AppDialogType.success,
            title: AppStrings.rewardRedeemed.tr(),
            description: AppStrings.rewardRedeemedDesc.tr(args: [code]),
            confirmText: AppStrings.continueText.tr(),
          );
        } else if (state.status == ProfileStatus.claimReferralResult && state.claimResult != null) {
          _handleClaimReferralResult(context, state.claimResult!);
        } else if (state.status == ProfileStatus.error && (state.errorMessage?.isNotEmpty ?? false)) {
          GameHudToast.show(
            context,
            state.errorMessage ?? '',
            type: ToastType.error,
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
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(RouterKeys.home);
              }
            },
          ),
          title: Text(
            AppStrings.loyaltyDashboard.tr(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            if (state.status == ProfileStatus.loading && state.user == null) {
              return const Center(child: AppLoader(size: 50));
            }

            if (state.status == ProfileStatus.error && state.user == null) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 50.sp),
                      SizedBox(height: 16.h),
                      AppText(
                        text: state.errorMessage ?? AppStrings.somethingWentWrong.tr(),
                        fontSize: 16.sp,
                        color: Colors.white,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20.h),
                      AppButton(
                        buttonConfig: ButtonConfig(
                          gradient: AppColors.primaryGradient,
                        ),
                        content: ButtonContent(
                          label: AppStrings.retry.tr(),
                        ),
                        behavior: ButtonBehavior.tap(
                          onTap: () => context.read<ProfileCubit>().getUserData(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Loyalty Status Header Card
                  const LoyaltyLevelCard(),
                  SizedBox(height: 16.h),

                  // Referral & Invitations Section
                  const ReferralCard(),
                  SizedBox(height: 20.h),

                  // Loyalty Missions Section
                  const LoyaltyMissionsSection(),
                  SizedBox(height: 20.h),

                  // Redeemable Rewards Header
                  AppText(
                    text: AppStrings.redeemPoints.tr(),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  SizedBox(height: 12.h),

                  // Rewards List
                  if (state.redemptionOptions.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        child: AppText(
                          text: AppStrings.noRewardsAvailable.tr(),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: state.redemptionOptions.map((option) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16.h),
                          child: _buildRedemptionCard(context, option, state.pointsBalance, isArabic),
                        );
                      }).toList(),
                    ),
                  const SafeBottomSpacer(extraPadding: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleClaimReferralResult(BuildContext context, ClaimReferralResult claimResult) {
    switch (claimResult.status) {
      case ClaimReferralStatus.success:
        GameHudToast.show(
          context,
          AppStrings.referralActivatedSuccess.tr(),
          type: ToastType.success,
        );
        break;
      case ClaimReferralStatus.alreadyClaimed:
        GameHudToast.show(
          context,
          AppStrings.referralAlreadyClaimed.tr(),
          type: ToastType.info,
        );
        break;
      case ClaimReferralStatus.emailUnconfirmed:
        AppDialog.show(
          context,
          type: AppDialogType.confirm,
          title: AppStrings.confirmEmailFirst.tr(),
          description: AppStrings.confirmEmailFirst.tr(),
          confirmText: AppStrings.resendVerificationEmail.tr(),
          onConfirm: () {
            try {
              sl<SignupCubit>().resendSignupOTP();
            } catch (_) {}
          },
        );
        break;
      case ClaimReferralStatus.invalidCode:
        GameHudToast.show(
          context,
          AppStrings.invalidReferralCode.tr(),
          type: ToastType.error,
        );
        break;
      case ClaimReferralStatus.error:
        GameHudToast.show(
          context,
          claimResult.messageKey.tr(),
          type: ToastType.error,
        );
        break;
    }
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
          Positioned(
            top: 0,
            right: isArabic ? null : 0,
            left: isArabic ? 0 : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
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
                        color: AppColors.neonBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
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
                                ? AppStrings.oneHourSession.tr() 
                                : AppStrings.egpDiscount.tr(args: [option.rewardValue.toInt().toString()]),
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
}
