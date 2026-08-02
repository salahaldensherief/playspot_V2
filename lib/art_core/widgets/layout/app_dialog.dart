import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../text/app_text.dart';
import '../buttons/app_button.dart';
import '../buttons/res/button_behavior.dart';
import '../buttons/res/button_content.dart';
import '../buttons/res/button_style_config.dart';

enum AppDialogType { success, error, confirm }

class AppDialog extends StatelessWidget {
  final AppDialogType type;
  final String title;
  final String description;
  final List<String>? titleArgs;
  final List<String>? descriptionArgs;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;

  const AppDialog({
    super.key,
    required this.type,
    required this.title,
    required this.description,
    this.titleArgs,
    this.descriptionArgs,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.icon,
  });

  static Future<void> show(
    BuildContext context, {
    required AppDialogType type,
    required String title,
    required String description,
    List<String>? titleArgs,
    List<String>? descriptionArgs,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    IconData? icon,
    bool barrierDismissible = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AppDialog(
        type: type,
        title: title,
        description: description,
        titleArgs: titleArgs,
        descriptionArgs: descriptionArgs,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.r20)),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.w24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            SizedBox(height: AppSizes.s24),
            AppText(
              text: title.tr(args: titleArgs),
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSizes.s12),
            AppText(
              text: description.tr(args: descriptionArgs),
              fontSize: 14.sp,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSizes.s32),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData displayIcon;
    Color color;

    switch (type) {
      case AppDialogType.success:
        displayIcon = icon ?? Icons.check_circle_rounded;
        color = AppColors.success;
        break;
      case AppDialogType.error:
        displayIcon = icon ?? Icons.error_outline_rounded;
        color = AppColors.danger;
        break;
      case AppDialogType.confirm:
        displayIcon = icon ?? Icons.warning_amber_rounded;
        color = AppColors.warning;
        break;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(displayIcon, color: color, size: 60.sp),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (type == AppDialogType.confirm) {
      return Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                onCancel?.call();
              },
              child: AppText(
                text: (cancelText ?? AppStrings.cancel).tr(),
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: AppSizes.w12),
          Expanded(
            child: AppButton(
              content: ButtonContent(label: (confirmText ?? AppStrings.next).tr()),
              behavior: ButtonBehavior.tap(
                onTap: () {
                  Navigator.pop(context);
                  onConfirm?.call();
                },
              ),
              buttonConfig: ButtonConfig(
                height: 45.h,
                backgroundColor: AppColors.danger,
                borderRadius: AppSizes.r12,
              ),
            ),
          ),
        ],
      );
    }

    return AppButton(
      content: ButtonContent(label: (confirmText ?? "Great!").tr()),
      behavior: ButtonBehavior.tap(
        onTap: () {
          Navigator.pop(context);
          onConfirm?.call();
        },
      ),
      buttonConfig: ButtonConfig(
        height: 50.h,
        borderRadius: AppSizes.r15,
        gradient: AppColors.primaryGradient,
      ),
    );
  }
}
