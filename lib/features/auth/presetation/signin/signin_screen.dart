import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/features/auth/presetation/signin/signin_cubit.dart';
import 'package:playspot/features/auth/presetation/signin/signin_state.dart';
import 'package:playspot/features/auth/presetation/signin/widgets/signin_form.dart';

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

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SignInCubit>(),
      child: const _SignInView(),
    );
  }
}

class _SignInView extends StatelessWidget {
  const _SignInView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignInCubit, LoginState>(
      listener: _handleStateChange,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              AuthAppBar(
                title: AppStrings.signIn.tr(),
                subTitle: AppStrings.signInSubtitle.tr(),
              ),
              180.verticalSpace,
              _SocialSection(),
              20.verticalSpace,
              Padding(
                padding: 16.horizontalPadding,
                child: const SignInForm(),
              ),
              20.verticalSpace,
              Padding(
                padding: 16.horizontalPadding,
                child: const _SignInButton(),
              ),
              20.verticalSpace,
              AppText(
                color: AppColors.white,
                onTap: () => context.goNamed(RouterKeys.signUp),
                text: AppStrings.dontHaveAccount.tr(),
              ),
              const SafeBottomSpacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, LoginState state) {
    if (state.status.isSuccess) {
      context.goNamed(RouterKeys.home);
    }
    if (state.status.isSuccessSocial) {
      if (state.params.isNewUser) {
        context.goNamed(RouterKeys.completeProfile, extra: state.params.id);
      } else {
        context.goNamed(RouterKeys.home);
      }
      return;
    }
    if (state.status.isFailure) {
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
    return BlocSelector<SignInCubit, LoginState, bool>(
      selector: (state) => state.status.isLoading,
      builder: (context, isLoading) {
        final cubit = context.read<SignInCubit>();
        return SocialButtons(
          googleOnTap: isLoading ? null : cubit.signInWithGoogle,
          facebookOnTap: isLoading ? null : cubit.signInWithFacebook,
        );
      },
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SignInCubit, LoginState, bool>(
      selector: (state) => state.status.isLoading,
      builder: (context, isLoading) {
        final cubit = context.read<SignInCubit>();
        return AppButton(
          buttonConfig: ButtonConfig.gradient(
            gradient: AppColors.primaryGradient,
            glowColor: AppColors.neonBlue,
            borderRadius: AppSizes.r15,
            width: double.infinity,
            height: 50.h,
          ),
          content: ButtonContent(label: AppStrings.signIn.tr()),
          behavior: TapBehavior(
            isEnabled: !isLoading,
            isLoading: isLoading,
            onTap: () {
              if (cubit.formKey.currentState?.validate() ?? false) {
                cubit.signInWithEmail(
                  email: cubit.emailController.text.trim(),
                  password: cubit.passwordController.text.trim(),
                );
              }
            },
          ),
        );
      },
    );
  }
}
