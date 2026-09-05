import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../profile_cubit.dart';
import '../profile_state.dart';

class ReferralCard extends StatelessWidget {
  const ReferralCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (previous, current) => previous.user != current.user,
      builder: (context, state) {
        final user = state.user;
        final referralCode = user?.referralCode ?? 'PLAYSPOT';

        return GlassContainer(
          borderRadius: 24.r,
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: AppColors.neonPurple.withValues(alpha: 0.3),
                width: 1.5,
              ),
              gradient: LinearGradient(
                colors: [
                  AppColors.neonPurple.withValues(alpha: 0.15),
                  AppColors.neonBlue.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColors.neonPurple.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.neonPurple.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        TablerIcons.gift,
                        color: AppColors.neonPurple,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            text: AppStrings.inviteFriends.tr(),
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          SizedBox(height: 2.h),
                          AppText(
                            text: AppStrings.yourReferralCode.tr(),
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                AppText(
                  text: AppStrings.referralSubtitle.tr(),
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                  height: 1.4,
                  maxLines: 5,
                ),
                SizedBox(height: 16.h),
                // Referral Code Box
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.neonPurple.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              TablerIcons.ticket,
                              color: AppColors.warning,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: AppText(
                                  text: referralCode,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neonBlue,
                                  letterSpacing: 1.1,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      InkWell(
                        onTap: () => _copyCode(context, referralCode),
                        borderRadius: BorderRadius.circular(8.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neonBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: AppColors.neonBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                TablerIcons.copy,
                                color: AppColors.neonBlue,
                                size: 14.sp,
                              ),
                              SizedBox(width: 4.w),
                              AppText(
                                text: AppStrings.copyCode.tr(),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.neonBlue,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                // Share Link Button
                AppButton(
                  buttonConfig: ButtonConfig(
                    gradient: const LinearGradient(
                      colors: [AppColors.neonPurple, AppColors.neonBlue],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  content: ButtonContent(
                    label: AppStrings.shareLink.tr(),
                    icon: Icon(TablerIcons.share, color: Colors.white, size: 18.sp),
                  ),
                  behavior: ButtonBehavior.tap(
                    onTap: () => _shareReferralLink(context, referralCode),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    GameHudToast.show(
      context,
      AppStrings.codeCopied.tr(),
      type: ToastType.success,
    );
  }

  Future<void> _shareReferralLink(BuildContext context, String code) async {
    final message = AppStrings.shareMessage.tr(args: [code]);
    try {
      await SharePlus.instance.share(ShareParams(text: message));
    } catch (e) {
      debugPrint(" [Referral] Share error: $e");
      if (context.mounted) {
        _copyCode(context, code);
      }
    }
  }
}
