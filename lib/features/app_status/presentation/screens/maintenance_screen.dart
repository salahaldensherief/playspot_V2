import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/font_manager.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/layout/glass_container.dart';
import '../../../../art_core/widgets/logo/logo_widget.dart';
import '../../domain/entities/app_status_entity.dart';

class MaintenanceScreen extends StatelessWidget {
  final AppStatusEntity? statusEntity;

  const MaintenanceScreen({super.key, this.statusEntity});

  Future<void> _contactSupport(BuildContext context) async {
    final supportNumber = statusEntity?.contactSupportNumber ?? '201000000000';
    final cleanNumber = supportNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final whatsappUri = Uri.parse(
      "https://wa.me/$cleanNumber?text=${Uri.encodeComponent('مرحباً فريق بلاي سبوت، أستفسر عن موعد انتهاء الصيانة.')}",
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        final telUri = Uri.parse("tel:$cleanNumber");
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = statusEntity?.maintenanceTitle?.isNotEmpty == true
        ? statusEntity!.maintenanceTitle!
        : AppStrings.maintenanceModeTitle.tr();

    final message = statusEntity?.maintenanceMessage?.isNotEmpty == true
        ? statusEntity!.maintenanceMessage!
        : AppStrings.maintenanceModeDesc.tr();

    final expectedTime = statusEntity?.expectedEndTime;

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
                      color: AppColors.primary.withValues(alpha: 0.6),
                      width: 2.w,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20.r,
                        spreadRadius: 2.r,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      TablerIcons.tools,
                      color: AppColors.primary,
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
                    fontFamily: context.locale.languageCode == 'ar'
                        ? FontsManager.arabicFontFamily
                        : 'Orbitron',
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
                if (expectedTime != null) ...[
                  24.verticalSpace,
                  GlassContainer(
                    borderRadius: 16.r,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    color: AppColors.cardBackground.withValues(alpha: 0.8),
                    borderColor: AppColors.primary.withValues(alpha: 0.3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          TablerIcons.clock,
                          color: AppColors.primary,
                          size: 20.r,
                        ),
                        10.horizontalSpace,
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              AppStrings.expectedReturnTime.tr(
                                args: [
                                  DateFormat(
                                    'yyyy-MM-dd hh:mm a',
                                    context.locale.languageCode,
                                  ).format(expectedTime.toLocal()),
                                ],
                              ),
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                AppButton(
                  content: ButtonContent(
                    label: AppStrings.contactSupport.tr(),
                    icon: Icon(
                      TablerIcons.brand_whatsapp,
                      color: AppColors.scaffoldBackground,
                      size: 20.r,
                    ),
                  ),
                  behavior: TapBehavior(
                    isEnabled: true,
                    onTap: () => _contactSupport(context),
                  ),
                  buttonConfig: ButtonConfig(
                    backgroundColor: AppColors.primary,
                    borderRadius: 12.r,
                    width: double.infinity,
                    height: 50.h,
                    textStyle: TextStyle(
                      color: AppColors.scaffoldBackground,
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
