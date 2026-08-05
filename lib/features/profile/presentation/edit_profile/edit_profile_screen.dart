import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/avatar_picker/avatar_picker_widget.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/core/di.dart';

import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../core/di/modules/auth_module.dart';
import 'edit_profile_cubit.dart';
import 'edit_profile_state.dart';
import '../widgets/edit_profile_form.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<EditProfileCubit>()..init(),
      child: const _EditProfileView(),
    );
  }
}

class _EditProfileView extends StatelessWidget {
  const _EditProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditProfileCubit, EditProfileState>(
      listener: _handleStateChange,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            AppStrings.editProfile.tr(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            children: [
              const _AvatarSection(),
              SizedBox(height: 30.h),
              _FormSection(),
              SizedBox(height: 40.h),
              const _SaveButton(),
              SizedBox(height: 20.h),
              const _DeleteAccountButton(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, EditProfileState state) {
    if (state.status == EditProfileStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context, true);
    } else if (state.status == EditProfileStatus.accountDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
      );
      context.goNamed(RouterKeys.signIn);
    } else if (state.status == EditProfileStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Error updating profile'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditProfileCubit, EditProfileState>(
      buildWhen: (previous, current) => previous.user?.avatarUrl != current.user?.avatarUrl || previous.status != current.status,
      builder: (context, state) {
        final cubit = context.read<EditProfileCubit>();
        return AvatarPickerWidget(
          avatarFile: cubit.avatarFile,
          imageUrl: state.user?.avatarUrl,
          onTap: cubit.pickAvatar,
          radius: 60,
        );
      },
    );
  }
}

class _FormSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EditProfileForm(cubit: context.read<EditProfileCubit>());
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EditProfileCubit, EditProfileState, bool>(
      selector: (state) => state.status == EditProfileStatus.loading,
      builder: (context, isLoading) {
        final cubit = context.read<EditProfileCubit>();
        return AppButton(
          buttonConfig: ButtonConfig.gradient(
            gradient: const LinearGradient(
              colors: [AppColors.neonBlue, AppColors.neonPurple],
            ),
            glowColor: AppColors.neonBlue,
            borderRadius: 15.r,
            width: double.infinity,
            height: 50.h,
          ),
          behavior: TapBehavior(
            isLoading: isLoading,
            onTap: cubit.updateProfile,
          ),
          content: ButtonContent(
            label: AppStrings.saveChanges.tr(),
          ),
        );
      },
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _showDeleteConfirmation(context),
      child: AppText(
        text: AppStrings.deleteAccount.tr(),
        color: AppColors.danger,
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final cubit = context.read<EditProfileCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: AppText(
          text: AppStrings.deleteAccount.tr(),
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        content: AppText(
          text: AppStrings.deleteAccountConfirmation.tr(),
          fontSize: 14.sp,
          color: AppColors.textSecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: AppText(text: AppStrings.cancel.tr(), color: Colors.white),
          ),
          TextButton(
            onPressed: () {
              cubit.deleteAccount();
              Navigator.pop(dialogContext);
            },
            child: AppText(
                text: AppStrings.deleteAccount.tr(), color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
