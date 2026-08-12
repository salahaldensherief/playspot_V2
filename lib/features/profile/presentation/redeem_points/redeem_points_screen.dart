import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/shimmer/redemption_option_shimmer.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';
import '../profile_cubit.dart';
import '../profile_state.dart';

class RedeemPointsScreen extends StatelessWidget {
  const RedeemPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == ProfileStatus.redeemSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.rewardRedeemed.tr())),
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
                      final canAfford = state.pointsBalance >= option.pointsCost;

                      return GlassContainer(
                        borderRadius: 20,
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Row(
                            children: [
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
                                    SizedBox(height: 4.h),
                                    AppText(
                                      text: option.getDescription(isArabic),
                                      fontSize: 12.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: 8.h),
                                    Row(
                                      children: [
                                        Icon(Icons.stars, color: AppColors.warning, size: 16.sp),
                                        SizedBox(width: 4.w),
                                        AppText(
                                          text: "${option.pointsCost} ${AppStrings.points.tr()}",
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.warning,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: canAfford
                                    ? () => context.read<ProfileCubit>().redeemPoints(option.id)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.neonBlue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Text(AppStrings.redeem.tr()),
                              ),
                            ],
                          ),
                        ),
                      );
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
