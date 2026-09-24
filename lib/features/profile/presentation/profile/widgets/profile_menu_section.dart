import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

class ProfileMenuSection extends StatelessWidget {
  const ProfileMenuSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context: context,
            icon: TablerIcons.heart,
            title: AppStrings.favorite.tr(),
            onTap: () => context.pushNamed(RouterKeys.favorites),
            showBorder: true,
          ),
          _buildMenuItem(
            context: context,
            icon: TablerIcons.stars,
            title: AppStrings.redeemPoints.tr(),
            onTap: () => context.pushNamed(RouterKeys.redeemPoints),
            showBorder: true,
          ),
          _buildMenuItem(
            context: context,
            icon: TablerIcons.history,
            title: AppStrings.pointsHistory.tr(),
            onTap: () => context.pushNamed(RouterKeys.pointsHistory),
            showBorder: true,
          ),
          _buildMenuItem(
            context: context,
            icon: TablerIcons.ticket,
            title: AppStrings.myRewards.tr(),
            onTap: () => context.pushNamed(RouterKeys.myVouchers),
            showBorder: true,
          ),
          _buildMenuItem(
            context: context,
            icon: TablerIcons.settings,
            title: AppStrings.settings.tr(),
            onTap: () => context.pushNamed(RouterKeys.notificationSettings),
            showBorder: true,
          ),
          _buildMenuItem(
            context: context,
            icon: TablerIcons.help,
            title: AppStrings.helpSupport.tr(),
            onTap: () => context.pushNamed(RouterKeys.helpSupport),
            showBorder: true,
          ),
          _buildMenuItem(
            context: context,
            icon: TablerIcons.file_text,
            title: AppStrings.termsOfService.tr(),
            onTap: () => context.pushNamed(RouterKeys.termsAndConditions),
            showBorder: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required bool showBorder,
  }) {
    final isRtl = context.locale.languageCode == 'ar';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
          decoration: BoxDecoration(
            border: showBorder
                ? const Border(bottom: BorderSide(color: AppColors.borderDefault))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.neonBlue, size: 22.sp),
              16.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: title,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    if (subtitle != null) ...[
                      2.verticalSpace,
                      AppText(
                        text: subtitle,
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                isRtl ? TablerIcons.chevron_left : TablerIcons.chevron_right,
                color: AppColors.textSecondary,
                size: 18.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
