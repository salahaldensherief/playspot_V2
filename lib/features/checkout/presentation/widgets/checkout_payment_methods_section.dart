import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/assets_manager.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

import '../checkout_cubit.dart';
import '../checkout_state.dart';

class CheckoutPaymentMethodsSection extends StatelessWidget {
  const CheckoutPaymentMethodsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) =>
          previous.selectedMethod != current.selectedMethod ||
          previous.allowCashPayment != current.allowCashPayment ||
          previous.isCashEnabled != current.isCashEnabled ||
          previous.cashDisabledReason != current.cashDisabledReason,
      builder: (context, state) {
        return Column(
          children: [
            _PaymentMethodCard(
              method: PaymentMethod.vodafoneCash,
              isSelected: state.selectedMethod == PaymentMethod.vodafoneCash ||
                  state.selectedMethod == PaymentMethod.instaPay,
              isEnabled: true,
              title: AppStrings.vodafoneCash.tr(),
              subtitle: AppStrings.vodafoneCashSubtitle.tr(),
              imagePath: AssetsManager.vodafoneCashLogo,
              secondImagePath: AssetsManager.instaPayLogo,
              imageFit: BoxFit.cover,
              padding: EdgeInsets.all(2.w),
              imageBorderRadius: 10.r,
              iconColor: AppColors.neonBlue,
            ),
            if (state.allowCashPayment) ...[
              SizedBox(height: 12.h),
              _PaymentMethodCard(
                method: PaymentMethod.cash,
                isSelected: state.selectedMethod == PaymentMethod.cash,
                isEnabled: state.isCashEnabled,
                title: AppStrings.cashAtLounge.tr(),
                subtitle: state.isCashEnabled
                    ? AppStrings.cashAtLoungeSubtitle.tr()
                    : AppStrings.cashDisabledFirstTime.tr(),
                icon: TablerIcons.cash,
                iconColor: state.isCashEnabled ? AppColors.success : AppColors.textSecondary,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final bool isEnabled;
  final String title;
  final String subtitle;
  final String? imagePath;
  final String? secondImagePath;
  final BoxFit imageFit;
  final EdgeInsets? padding;
  final double? imageBorderRadius;
  final IconData? icon;
  final Color iconColor;

  const _PaymentMethodCard({
    required this.method,
    required this.isSelected,
    required this.isEnabled,
    required this.title,
    required this.subtitle,
    this.imagePath,
    this.secondImagePath,
    this.imageFit = BoxFit.contain,
    this.padding,
    this.imageBorderRadius,
    this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = iconColor.withValues(alpha: 0.18);
    final effectivePadding = padding ?? (imagePath != null ? EdgeInsets.all(4.w) : EdgeInsets.all(10.w));

    return InkWell(
      onTap: isEnabled
          ? () => context.read<CheckoutCubit>().selectPaymentMethod(method)
          : () {
              HapticFeedback.vibrate();
              GameHudToast.show(
                context,
                AppStrings.cashDisabledFirstTime.tr(),
                type: ToastType.warning,
              );
            },
      borderRadius: BorderRadius.circular(16.r),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isSelected
                ? iconColor.withValues(alpha: 0.12)
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected ? iconColor : AppColors.borderDefault,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              if (secondImagePath != null) ...[
                Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.asset(
                          imagePath!,
                          width: 26.w,
                          height: 26.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: Image.asset(
                            secondImagePath!,
                            width: 22.w,
                            height: 22.w,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: 44.w,
                  height: 44.w,
                  padding: effectivePadding,
                  decoration: BoxDecoration(
                    color: effectiveBgColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(imageBorderRadius ?? 8.r),
                    child: imagePath != null
                        ? Image.asset(
                            imagePath!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: imageFit,
                          )
                        : Center(
                            child: Icon(icon, color: iconColor, size: 22.sp),
                          ),
                  ),
                ),
              ],
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: title,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: isEnabled ? Colors.white : AppColors.textSecondary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    AppText(
                      text: subtitle,
                      fontSize: 12.sp,
                      color: !isEnabled ? AppColors.warning : AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                width: 22.r,
                height: 22.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? iconColor : AppColors.textSecondary,
                    width: isSelected ? 6.r : 1.5.r,
                  ),
                  color: isSelected ? Colors.white : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
