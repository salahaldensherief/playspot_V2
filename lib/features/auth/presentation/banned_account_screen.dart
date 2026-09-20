import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/core/services/contact_launcher_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BannedAccountScreen extends StatelessWidget {
  final String? reason;

  const BannedAccountScreen({
    super.key,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.35),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      blurRadius: 16.r,
                      spreadRadius: 2.r,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.block_rounded,
                  color: AppColors.danger,
                  size: 64.sp,
                ),
              ),
              SizedBox(height: 28.h),
              AppText(
                text: AppStrings.accountBannedTitle.tr(),
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              AppText(
                text: AppStrings.accountBannedMsg.tr(),
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
                height: 1.5,
              ),
              if (reason != null && reason!.trim().isNotEmpty) ...[
                SizedBox(height: 24.h),
                GlassContainer(
                  borderRadius: 16,
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          text: AppStrings.bannedReasonLabel.tr(),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                        ),
                        SizedBox(height: 6.h),
                        AppText(
                          text: reason!.trim(),
                          fontSize: 12.5.sp,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              AppButton(
                content: ButtonContent(
                  label: AppStrings.supportContactUs.tr(),
                  icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
                ),
                behavior: ButtonBehavior.tap(
                  onTap: () {
                    ContactLauncherService.launchWhatsApp(
                      phone: '01012345678',
                      message: 'مرحباً فِريق دعم PlaySpot 👋\nتم حظر حسابي وأود الاستفسار حول ذلك.',
                    );
                  },
                ),
                buttonConfig: ButtonConfig(
                  height: 52.h,
                  borderRadius: 14.r,
                  gradient: const LinearGradient(
                    colors: [AppColors.neonBlue, AppColors.neonPurple],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              AppButton(
                content: ButtonContent(
                  label: AppStrings.logOut.tr(),
                ),
                behavior: ButtonBehavior.tap(
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      context.goNamed(RouterKeys.signIn);
                    }
                  },
                ),
                buttonConfig: ButtonConfig(
                  height: 48.h,
                  backgroundColor: Colors.transparent,
                  borderColor: AppColors.borderDefault,
                  borderRadius: 14.r,
                  textStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              const SafeBottomSpacer(extraPadding: 20),
            ],
          ),
        ),
      ),
    );
  }
}
