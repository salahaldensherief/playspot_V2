import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../../art_core/widgets/text/app_text.dart';

class QuickRebookActions extends StatelessWidget {
  final bool canCheckout;
  final VoidCallback onCheckout;
  final VoidCallback onCustomize;

  const QuickRebookActions({
    super.key,
    required this.canCheckout,
    required this.onCheckout,
    required this.onCustomize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.neonBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: AppColors.neonBlue.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: AppColors.neonBlue,
                size: 18.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: AppText(
                  text: AppStrings.quickRebookPricingAtCheckout.tr(),
                  fontSize: 12.sp,
                  color: Colors.white70,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        AppButton(
          content: ButtonContent(
            label: AppStrings.instantCheckout.tr(),
            icon: Icon(
              Icons.flash_on_rounded,
              color: Colors.black,
              size: 18.sp,
            ),
          ),
          buttonConfig: ButtonConfig(
            height: 48.h,
            backgroundColor:
                canCheckout ? AppColors.neonBlue : Colors.white24,
            borderRadius: 14.r,
          ),
          behavior: ButtonBehavior.tap(
            isEnabled: canCheckout,
            onTap: canCheckout ? onCheckout : null,
          ),
        ),
        SizedBox(height: 10.h),
        AppButton(
          content: ButtonContent(
            label: AppStrings.quickRebookCustomize.tr(),
          ),
          buttonConfig: ButtonConfig(
            height: 42.h,
            backgroundColor: Colors.transparent,
            borderColor: AppColors.borderDefault,
            borderRadius: 12.r,
          ),
          behavior: ButtonBehavior.tap(
            onTap: onCustomize,
          ),
        ),
      ],
    );
  }
}
