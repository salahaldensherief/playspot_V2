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
import '../../../../art_core/widgets/logo/logo_widget.dart';
import '../../domain/entities/app_status_entity.dart';

class ForceUpdateScreen extends StatelessWidget {
  final AppStatusEntity? statusEntity;
  final String currentVersion;

  const ForceUpdateScreen({
    super.key,
    this.statusEntity,
    this.currentVersion = '1.0.0',
  });

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
    final title = AppStrings.updateRequiredTitle.tr();
    final message = statusEntity?.updateMessage?.isNotEmpty == true
        ? statusEntity!.updateMessage!
        : AppStrings.updateRequiredDesc.tr();

    final minVersion = statusEntity?.minSupportedVersion ?? '1.0.0';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                LogoWidget(
                  animate: false,
                  iconColor: AppColors.primary,
                  fontSize: 32.sp,
                  width: 32.w,
                  height: 32.h,
                ),
                32.verticalSpace,
                Container(
                  width: 110.r,
                  height: 110.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cardBackground,
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.8),
                      width: 2.w,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purple.withValues(alpha: 0.4),
                        blurRadius: 20.r,
                        spreadRadius: 2.r,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      TablerIcons.rocket,
                      color: AppColors.purple,
                      size: 52.r,
                    ),
                  ),
                ),
                28.verticalSpace,
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: context.locale.languageCode == 'ar' ? 'Cairo' : 'Orbitron',
                  ),
                ),
                12.verticalSpace,
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                ),
                24.verticalSpace,
                GlassContainer(
                  borderRadius: 16.r,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  color: AppColors.cardBackground.withValues(alpha: 0.8),
                  borderColor: AppColors.purple.withValues(alpha: 0.3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'v$currentVersion',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      12.horizontalSpace,
                      Icon(
                        TablerIcons.arrow_right,
                        color: AppColors.purple,
                        size: 18.r,
                      ),
                      12.horizontalSpace,
                      Text(
                        'v$minVersion+',
                        style: TextStyle(
                          color: AppColors.purple,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                AppButton(
                  content: ButtonContent(
                    label: AppStrings.updateNow.tr(),
                    icon: Icon(TablerIcons.download, color: Colors.white, size: 20.r),
                  ),
                  behavior: TapBehavior(
                    isEnabled: true,
                    onTap: _openStore,
                  ),
                  buttonConfig: ButtonConfig(
                    backgroundColor: AppColors.purple,
                    borderRadius: 12.r,
                    width: double.infinity,
                    height: 50.h,
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                16.verticalSpace,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
