import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';

import 'widgets/profile_logout_listener.dart';
import 'widgets/logout_button.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_menu_section.dart';
import 'widgets/referral_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileLogoutListener(
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: 20.allPadding,
            child: Column(
              children: [
                const ProfileHeader(),
                24.verticalSpace,
                const ReferralCard(),
                24.verticalSpace,
                const ProfileMenuSection(),
                30.verticalSpace,
                const LogoutButton(),
                const SafeBottomSpacer(extraPadding: 150, androidOnly: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
