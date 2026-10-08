import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/core/services/contact_launcher_service.dart';

class LoungeTechnicalIssueBanner extends StatelessWidget {
  final String? contactPhone;
  final VoidCallback? onRetry;

  const LoungeTechnicalIssueBanner({
    super.key,
    this.contactPhone,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final phone = contactPhone?.trim() ?? '';
    final hasPhone = phone.isNotEmpty;

    final message = hasPhone
        ? AppStrings.loungeTechnicalIssueCallToBook.tr(
            namedArgs: {'phone': phone},
          )
        : AppStrings.loungeTechnicalIssue.tr();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: AppColors.warning,
                size: 22.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (hasPhone) ...[
            SizedBox(height: 12.h),
            AppButton(
              content: ButtonContent(
                label: AppStrings.callLounge.tr(),
                icon: const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: AppColors.black,
                ),
              ),
              behavior: ButtonBehavior.tap(
                onTap: () => ContactLauncherService.launchPhoneCall(phone),
              ),
              buttonConfig: ButtonConfig(
                height: 42.h,
                backgroundColor: AppColors.warning,
                borderRadius: 8.r,
                textStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
            ),
          ],
          if (onRetry != null) ...[
            SizedBox(height: 8.h),
            AppButton(
              content: ButtonContent(label: 'retry'.tr()),
              behavior: ButtonBehavior.tap(onTap: onRetry),
              buttonConfig: ButtonConfig(
                height: 48,
                isOutlined: true,
                backgroundColor: Colors.transparent,
                borderColor: AppColors.warning,
                borderRadius: 8.r,
                textStyle: TextStyle(color: AppColors.warning, fontSize: 12.sp),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
