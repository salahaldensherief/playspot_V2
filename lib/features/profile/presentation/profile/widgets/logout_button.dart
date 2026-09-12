import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_dialog.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import '../profile_cubit.dart';
import '../profile_state.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (previous, current) => previous.status != current.status,
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
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.status == ProfileStatus.loading)
                   SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const AppLoader(
                      size: 20,
                      strokeWidth: 2,
                      color: AppColors.danger,
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
    AppDialog.show(
      context,
      type: AppDialogType.confirm,
      title: AppStrings.logOut,
      description: AppStrings.logoutConfirmation,
      confirmText: AppStrings.logOut,
      cancelText: AppStrings.cancel,
      onConfirm: () {
        context.read<ProfileCubit>().logout();
      },
    );
  }
}
