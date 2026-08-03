import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';

import '../../../../art_core/cubit/locale_cubit.dart';

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
            title: AppStrings.redeemPoints.tr(),
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
            subtitle: context.locale.languageCode == 'ar' ? 'العربية' : 'English',
            onTap: () => _showLanguagePicker(context),
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

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              text: AppStrings.language.tr(),
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            SizedBox(height: 24.h),
            _buildLanguageOption(
              context,
              title: 'English',
              isSelected: context.locale.languageCode == 'en',
              onTap: () {
                context.read<LocaleCubit>().setLocale(context, 'en');
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 12.h),
            _buildLanguageOption(
              context,
              title: 'العربية',
              isSelected: context.locale.languageCode == 'ar',
              onTap: () {
                context.read<LocaleCubit>().setLocale(context, 'ar');
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonBlue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.neonBlue : AppColors.borderDefault,
          ),
        ),
        child: Row(
          children: [
            AppText(
              text: title,
              fontSize: 16.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.neonBlue : Colors.white,
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.neonBlue, size: 20.sp),
          ],
        ),
      ),
    );
  }
}
