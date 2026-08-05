import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/glass_container.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.8, -0.8),
            radius: 1.5,
            colors: [
              AppColors.neonBlue.withOpacity(0.05),
              AppColors.scaffoldBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20.w),
                  child: GlassContainer(
                    borderRadius: 24,
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            "1. Acceptance of Terms",
                            "By accessing and using PlaySpot, you agree to be bound by these Terms and Conditions and all applicable laws and regulations.",
                          ),
                          _buildSection(
                            "2. Booking Policy",
                            "All bookings are subject to availability. Cancellations must be made at least 2 hours before the scheduled time for a full refund.",
                          ),
                          _buildSection(
                            "3. User Conduct",
                            "Users are expected to maintain respect for the lounge facilities and other players. Any damage to equipment will be the responsibility of the user.",
                          ),
                          _buildSection(
                            "4. Privacy",
                            "Your privacy is important to us. Please review our Privacy Policy to understand how we collect and use your data.",
                          ),
                          _buildSection(
                            "5. Rewards & Points",
                            "Points earned through the loyalty program have no cash value and can only be redeemed for rewards within the app.",
                          ),
                          _buildSection(
                            "6. Changes to Terms",
                            "PlaySpot reserves the right to modify these terms at any time. Continued use of the app constitutes acceptance of the updated terms.",
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(TablerIcons.chevron_left, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          SizedBox(width: 16.w),
          AppText(
            text: AppStrings.termsOfService.tr(),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: "Orbitron",
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            text: title,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.neonBlue,
          ),
          SizedBox(height: 8.h),
          AppText(
            text: content,
            fontSize: 14.sp,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ],
      ),
    );
  }
}
