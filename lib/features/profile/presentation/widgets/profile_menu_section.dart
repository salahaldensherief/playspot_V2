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
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: TablerIcons.calendar,
            title: AppStrings.myBookings.tr(),
            onTap: () => context.pushNamed(RouterKeys.myBookings),
            showBorder: true,
          ),
          _buildMenuItem(
            icon: TablerIcons.heart,
            title: AppStrings.favorite.tr(),
            onTap: () => context.pushNamed(RouterKeys.favorites),
            showBorder: true,
          ),
          _buildMenuItem(
            icon: TablerIcons.stars,
            title: "Redeem Points",
            onTap: () => context.pushNamed(RouterKeys.redeemPoints),
            showBorder: true,
          ),
          _buildMenuItem(
            icon: TablerIcons.credit_card,
            title: AppStrings.paymentMethods.tr(),
            onTap: () {},
            showBorder: true,
          ),
          _buildMenuItem(
            icon: TablerIcons.bell,
            title: AppStrings.notifications.tr(),
            onTap: () {},
            showBorder: true,
          ),
          _buildMenuItem(
            icon: TablerIcons.world,
            title: AppStrings.language.tr(),
            subtitle: AppStrings.arabicEnglish.tr(),
            onTap: () {},
            showBorder: true,
          ),
          _buildMenuItem(
            icon: TablerIcons.help,
            title: AppStrings.helpSupport.tr(),
            onTap: () {},
            showBorder: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required bool showBorder,
  }) {
    return GestureDetector(
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
            SizedBox(width: 16.w),
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
                    SizedBox(height: 2.h),
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
              TablerIcons.chevron_right,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}
