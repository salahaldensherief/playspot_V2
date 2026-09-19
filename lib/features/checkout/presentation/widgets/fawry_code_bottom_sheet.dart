import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class FawryCodeBottomSheet extends StatelessWidget {
  final String fawryCode;
  final double amount;
  final VoidCallback onDone;

  const FawryCodeBottomSheet({
    super.key,
    required this.fawryCode,
    required this.amount,
    required this.onDone,
  });

  static Future<void> show({
    required BuildContext context,
    required String fawryCode,
    required double amount,
    required VoidCallback onDone,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.scaffoldBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => FawryCodeBottomSheet(
        fawryCode: fawryCode,
        amount: amount,
        onDone: onDone,
      ),
    );
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: fawryCode));
    HapticFeedback.lightImpact();
    GameHudToast.show(
      context,
      AppStrings.codeCopied.tr(),
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(TablerIcons.building_bank, color: Colors.amber, size: 32.sp),
          ),
          SizedBox(height: 12.h),
          AppText(
            text: AppStrings.fawryPaymentTitle.tr(),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          SizedBox(height: 20.h),
          GlassContainer(
            borderRadius: 20,
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                children: [
                  AppText(
                    text: AppStrings.fawryCodeLabel.tr(),
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 8.h),
                  AppText(
                    text: fawryCode,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.neonBlue,
                    letterSpacing: 3,
                  ),
                  SizedBox(height: 16.h),
                  AppButton(
                    content: ButtonContent(
                      label: AppStrings.copyCode.tr(),
                      icon: Icon(TablerIcons.copy, size: 16.sp, color: AppColors.neonBlue),
                    ),
                    buttonConfig: ButtonConfig(
                      height: 40.h,
                      backgroundColor: AppColors.neonBlue.withValues(alpha: 0.15),
                      borderColor: AppColors.neonBlue.withValues(alpha: 0.3),
                      borderRadius: 10.r,
                      textStyle: TextStyle(color: AppColors.neonBlue, fontSize: 13.sp, fontWeight: FontWeight.bold),
                    ),
                    behavior: ButtonBehavior.tap(
                      onTap: () => _copyCode(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: AppText(
                    text: AppStrings.fawryInstructions.tr(),
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          AppButton(
            content: ButtonContent(
              label: AppStrings.viewMyBookings.tr(),
            ),
            buttonConfig: ButtonConfig(
              height: 50.h,
              gradient: AppColors.primaryGradient,
              borderRadius: 14.r,
            ),
            behavior: ButtonBehavior.tap(
              onTap: () {
                Navigator.pop(context);
                onDone();
              },
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}
