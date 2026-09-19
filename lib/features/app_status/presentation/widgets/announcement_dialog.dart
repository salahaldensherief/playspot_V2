import 'package:cached_network_image/cached_network_image.dart';
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

class AnnouncementDialog extends StatelessWidget {
  final String title;
  final String body;
  final String? imageUrl;
  final String? actionUrl;

  const AnnouncementDialog({
    super.key,
    required this.title,
    required this.body,
    this.imageUrl,
    this.actionUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String body,
    String? imageUrl,
    String? actionUrl,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AnnouncementDialog(
        title: title,
        body: body,
        imageUrl: imageUrl,
        actionUrl: actionUrl,
      ),
    );
  }

  Future<void> _handleAction() async {
    if (actionUrl != null && actionUrl!.isNotEmpty) {
      final uri = Uri.parse(actionUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GlassContainer(
        borderRadius: 24.r,
        padding: EdgeInsets.zero,
        color: AppColors.cardBackground.withValues(alpha: 0.95),
        borderColor: AppColors.primary.withValues(alpha: 0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  height: 180.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              16.verticalSpace,
            ] else ...[
              20.verticalSpace,
              Center(
                child: Container(
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    TablerIcons.speakerphone,
                    color: AppColors.primary,
                    size: 32.r,
                  ),
                ),
              ),
              12.verticalSpace,
            ],
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  10.verticalSpace,
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.sp,
                      height: 1.4,
                    ),
                  ),
                  20.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            AppStrings.close.tr(),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ),
                      if (actionUrl != null && actionUrl!.isNotEmpty) ...[
                        12.horizontalSpace,
                        Expanded(
                          child: AppButton(
                            content: ButtonContent(
                              label: AppStrings.next.tr(),
                            ),
                            behavior: TapBehavior(
                              isEnabled: true,
                              onTap: () {
                                Navigator.of(context).pop();
                                _handleAction();
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
                    ],
                  ),
                  20.verticalSpace,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
