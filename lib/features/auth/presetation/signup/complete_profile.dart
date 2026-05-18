import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/widgets/avatar_picker/avatar_picker_widget.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/router/router_keys.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/text_field/app_text_field.dart';
import '../../../../core/di.dart';
import '../signup/signup_cubit.dart';
import '../signup/signup_state.dart';
import '../widgets/auth_app_bar.dart';

class CompleteProfileScreen extends StatelessWidget {
  final String userId;

  const CompleteProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SignupCubit>()..setUserId(userId),
      child: const _CompleteProfileView(),
    );
  }
}

class _CompleteProfileView extends StatelessWidget {
  const _CompleteProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignupCubit, SignupState>(
      listener: _handleStateChange,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                AuthAppBar(
                  title: AppStrings.completeProfile.tr(),
                  subTitle: AppStrings.completeProfileSubtitle.tr(),
                ),
                SizedBox(height: 200.h),
                const _AvatarSection(),
                SizedBox(height: 40.h),
                const _PhoneSection(),
                SizedBox(height: 30.h),
                const _ContinueButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, SignupState state) {
    if (state.status == SignupStatus.success) {
      context.goNamed(RouterKeys.home);
    }
    if (state.status == SignupStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Something went wrong'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

// ─── Avatar Section ───────────────────────────────────────────
class _AvatarSection extends StatelessWidget {
  const _AvatarSection();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SignupCubit, SignupState, String?>(
      selector: (state) => state.params.avatarUrl,
      builder: (context, _) {
        final cubit = context.read<SignupCubit>();
        return AvatarPickerWidget(
          avatarFile: cubit.avatarFile,
          onTap: cubit.pickAvatar,
        );
      },
    );
  }
}

// ─── Phone Section ────────────────────────────────────────────
class _PhoneSection extends StatelessWidget {
  const _PhoneSection();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignupCubit>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: AppTextField(
        controller: cubit.phoneController,
        contentPadding: const EdgeInsets.all(4),
        label: AppStrings.phone.tr(),
        isRequired: true,
        textInputType: TextInputType.phone,
        hint: AppStrings.pleaseEnterPhoneNum.tr(),
      ),
    );
  }
}

// ─── Continue Button ──────────────────────────────────────────
class _ContinueButton extends StatelessWidget {
  const _ContinueButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: BlocSelector<SignupCubit, SignupState, bool>(
        selector: (state) => state.status == SignupStatus.loading,
        builder: (context, isLoading) {
          final cubit = context.read<SignupCubit>();
          return AppButton(
            buttonConfig: ButtonConfig.gradient(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF9B59B6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              glowColor: const Color(0xFF00D4FF),
              borderRadius: 15.r,
              width: 340.w,
              height: 50.h,
            ),
            content: ButtonContent(label: AppStrings.continueText.tr()),
            behavior: TapBehavior(
              isEnabled: !isLoading,
              isLoading: isLoading,
              onTap: cubit.completeProfile,
            ),
          );
        },
      ),
    );
  }
}
