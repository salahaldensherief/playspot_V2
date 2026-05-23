import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/art_core/router/router_keys.dart';

import 'profile_cubit.dart';
import 'profile_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<ProfileCubit>()..getUserData(),
      child: BlocListener<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state.status == ProfileStatus.logoutSuccess) {
            context.goNamed(RouterKeys.signIn);
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                children: [
                  _buildHeader(context),
                  SizedBox(height: 30.h),
                  _buildStatsRow(),
                  SizedBox(height: 30.h),
                  _buildMenuSection(context),
                  SizedBox(height: 30.h),
                  _buildLogoutButton(context),
                  SizedBox(height: 100.h), // Spacing for bottom nav bar
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final user = state.user;
        final profileImageUrl = user?.avatarUrl;
        final name = user?.name ?? "User";
        final phone = user?.phone ?? "";
        final initials = name.isNotEmpty
            ? name
                  .trim()
                  .split(' ')
                  .map((e) => e[0])
                  .take(2)
                  .join()
                  .toUpperCase()
            : "U";

        return Row(
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.neonBlue, AppColors.neonPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: profileImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(40.w),
                      child: CachedNetworkImage(
                        imageUrl: profileImageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        errorWidget: (context, url, error) => Text(
                          initials,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    text: name,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  SizedBox(height: 4.h),
                  AppText(
                    text: phone,
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Icon(
                TablerIcons.pencil,
                color: AppColors.neonBlue,
                size: 20.sp,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard(
          TablerIcons.calendar,
          "12",
          AppStrings.totalBookings.tr(),
          AppColors.neonBlue,
        ),
        _buildStatCard(
          TablerIcons.clock,
          "48",
          AppStrings.hoursPlayed.tr(),
          AppColors.neonPurple,
        ),
        _buildStatCard(
          TablerIcons.map_pin,
          "GameZone",
          AppStrings.favorite.tr(),
          AppColors.neonBlue,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      width: 105.w,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 12.h),
          AppText(
            text: value,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          SizedBox(height: 4.h),
          AppText(
            text: label,
            fontSize: 10.sp,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
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
            onTap: () {},
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
              ? Border(bottom: BorderSide(color: AppColors.borderDefault))
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

  Widget _buildLogoutButton(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        return GestureDetector(
          onTap: state.status == ProfileStatus.loading
              ? null
              : () => _showLogoutConfirmation(context),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.status == ProfileStatus.loading)
                  SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.danger,
                      ),
                    ),
                  )
                else ...[
                  Icon(
                    TablerIcons.logout,
                    color: AppColors.danger,
                    size: 22.sp,
                  ),
                  SizedBox(width: 12.w),
                  AppText(
                    text: AppStrings.logOut.tr(),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: AppText(
          text: AppStrings.logOut.tr(),
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        content: AppText(
          text: AppStrings.logoutConfirmation.tr(),
          fontSize: 14.sp,
          color: AppColors.textSecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: AppText(text: AppStrings.cancel.tr(), color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ProfileCubit>().logout();
            },
            child: AppText(
              text: AppStrings.logOut.tr(),
              color: AppColors.danger,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
