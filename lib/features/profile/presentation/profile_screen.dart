import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';

import 'profile_cubit.dart';
import 'profile_state.dart';
import 'widgets/logout_button.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_menu_section.dart';
import 'widgets/profile_stats_row.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state.status == ProfileStatus.logoutSuccess) {
          context.goNamed(RouterKeys.signIn);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: 20.allPadding,
            child: Column(
              children: [
                const ProfileHeader(),
                24.verticalSpace,
                const ProfileStatsRow(),
                30.verticalSpace,
                const ProfileMenuSection(),
                30.verticalSpace,
                const LogoutButton(),
                const SafeBottomSpacer(extraPadding: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
