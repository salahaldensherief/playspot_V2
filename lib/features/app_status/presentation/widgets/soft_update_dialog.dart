import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';
import '../../domain/entities/app_status_entity.dart';

import '../../../../art_core/widgets/text/app_text.dart';

class SoftUpdateDialog extends StatelessWidget {
  final AppStatusEntity? statusEntity;
  final VoidCallback onDismiss;

  const SoftUpdateDialog({
    super.key,
    this.statusEntity,
    required this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    AppStatusEntity? statusEntity,
    required VoidCallback onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => SoftUpdateDialog(
        statusEntity: statusEntity,
        onDismiss: onDismiss,
      ),
    );
  }

  Future<void> _openStore() async {
    String? url;
    if (Platform.isAndroid) {
      url = statusEntity?.storeUrlAndroid ?? 'https://play.google.com/store/apps/details?id=com.playspot.app';
    } else if (Platform.isIOS) {
      url = statusEntity?.storeUrlIos ?? 'https://apps.apple.com/app/playspot/id123456789';
    } else {
      url = statusEntity?.storeUrlAndroid;
    }

    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = AppStrings.newUpdateAvailableTitle.tr();
    final message = statusEntity?.updateMessage?.isNotEmpty == true
        ? statusEntity!.updateMessage!
        : AppStrings.newUpdateAvailableDesc.tr();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: GlassContainer(
        borderRadius: 24.r,
        padding: EdgeInsets.all(24.r),
        color: AppColors.cardBackground.withValues(alpha: 0.95),
        borderColor: AppColors.primary.withValues(alpha: 0.4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 1.5.w,
                ),
              ),
              child: Icon(
                TablerIcons.sparkles,
                color: AppColors.primary,
                size: 36.r,
              ),
            ),
            16.verticalSpace,
            AppText(
              text: title,
              textAlign: TextAlign.center,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            10.verticalSpace,
            AppText(
              text: message,
              textAlign: TextAlign.center,
              fontSize: 13.sp,
              color: AppColors.textSecondary,
            ),
            24.verticalSpace,
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    buttonConfig: ButtonConfig(
                      backgroundColor: Colors.transparent,
                      borderColor: AppColors.textSecondary.withValues(alpha: 0.3),
                      isOutlined: true,
                      height: 48.h,
                      borderRadius: 12.r,
                    ),
                    content: ButtonContent(
                      label: AppStrings.later.tr(),
                    ),
                    behavior: TapBehavior(
                      onTap: () {
                        Navigator.of(context).pop();
                        onDismiss();
                      },
                    ),
                  ),
                ),
                12.horizontalSpace,
                Expanded(
                  child: AppButton(
                    content: ButtonContent(
                      label: AppStrings.updateNow.tr(),
                    ),
                    behavior: TapBehavior(
                      isEnabled: true,
                      onTap: () {
                        Navigator.of(context).pop();
                        _openStore();
                      },
                    ),
                    buttonConfig: ButtonConfig(
                      backgroundColor: AppColors.primary,
                      borderRadius: 12.r,
                      height: 48.h,
                      textStyle: TextStyle(
                        color: AppColors.scaffoldBackground,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
