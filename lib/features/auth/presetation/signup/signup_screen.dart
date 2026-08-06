import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/avatar_picker/avatar_picker_widget.dart';
import 'package:playspot/features/auth/presetation/signup/signup_cubit.dart';
import 'package:playspot/features/auth/presetation/signup/signup_state.dart';
import 'package:playspot/features/auth/presetation/signup/widgets/signup_form.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../../../../core/di.dart';
import '../widgets/auth_app_bar.dart';
import '../widgets/social_buttons.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SignupCubit>(),
      child: const _SignUpView(),
    );
  }
}

class _SignUpView extends StatelessWidget {
  const _SignUpView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignupCubit, SignupState>(
      listener: _handleStateChange,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              AuthAppBar(
                title: AppStrings.createAnAcc.tr(),
                subTitle: AppStrings.signUpSubtitle.tr(),
              ),
              180.verticalSpace,
              _SocialSection(),
              20.verticalSpace,
              BlocSelector<SignupCubit, SignupState, String?>(
                selector: (state) => state.params.avatarUrl,
                builder: (context, _) {
                  final cubit = context.read<SignupCubit>();
                  return AvatarPickerWidget(
                    avatarFile: cubit.avatarFile,
                    onTap: cubit.pickAvatar,
                  );
                },
              ),
              20.verticalSpace,
              Padding(
                padding: 16.horizontalPadding,
                child: SignUpForm(cubit: context.read<SignupCubit>()),
              ),
              20.verticalSpace,
              Padding(
                padding: 16.horizontalPadding,
                child: const _SignUpButton(),
              ),
              20.verticalSpace,
              AppText(
                color: AppColors.white,
                onTap: () => context.goNamed(RouterKeys.signIn),
                text: AppStrings.alreadyHaveAccount.tr(),
              ),
              20.verticalSpace,
            ],
          ),
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, SignupState state) {
    if (state.status == SignupStatus.success) {
      context.goNamed(RouterKeys.home);
    }

    if (state.status == SignupStatus.successSocial) {
      context.goNamed(
        RouterKeys.completeProfile,
        extra: state.params.id,
      );
    }

    if (state.status == SignupStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? AppStrings.somethingWentWrong.tr()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _SocialSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignupCubit>();
    return SocialButtons(
      googleOnTap: cubit.signUpWithGoogle,
      facebookOnTap: cubit.signUpWithFacebook,
    );
  }
}

class _SignUpButton extends StatelessWidget {
  const _SignUpButton();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SignupCubit, SignupState, bool>(
      selector: (state) => state.status == SignupStatus.loading,
      builder: (context, isLoading) {
        final cubit = context.read<SignupCubit>();
        return AppButton(
          buttonConfig: ButtonConfig.gradient(
            gradient: AppColors.primaryGradient,
            glowColor: AppColors.neonBlue,
            borderRadius: AppSizes.r15,
            width: double.infinity,
            height: 50.h,
          ),
          content: ButtonContent(
            label: AppStrings.createAcc.tr(),
          ),
          behavior: TapBehavior(
            isEnabled: !isLoading,
            isLoading: isLoading,
            onTap: () {
              if (cubit.formKey.currentState?.validate() ?? false) {
                cubit.signUpWithEmail();
              }
            },
          ),
        );
      },
    );
  }
}
