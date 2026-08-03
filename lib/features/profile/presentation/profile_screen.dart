import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/art_core/router/router_keys.dart';

import '../../../core/di/modules/auth_module.dart';
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
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                const ProfileHeader(),
                SizedBox(height: 24.h),
                const ProfileStatsRow(),
                SizedBox(height: 30.h),
                const ProfileMenuSection(),
                SizedBox(height: 30.h),
                const LogoutButton(),
                SizedBox(height: 100.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
