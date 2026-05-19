import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
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
import '../signup/widgets/signup_form.dart';
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
              SizedBox(height: 180.h),
              _SocialSection(),
              _space(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: const SignInForm(),
              ),
              _space(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: const _SignInButton(),
              ),
              _space(),
              AppText(
                color: AppColors.white,
                onTap: () => context.goNamed(RouterKeys.signUp),
                text: AppStrings.dontHaveAccount.tr(),
              ),
              _space(),
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
      context.goNamed(
        RouterKeys.completeProfile,
        extra: state.params?.id,
      );
    }

    if (state.status.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Something went wrong'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _SocialSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignInCubit>();
    return SocialButtons(
      googleOnTap: cubit.signInWithGoogle,
      facebookOnTap: cubit.signInWithFacebook,
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

Widget _space({double? height}) => SizedBox(height: height ?? 20.0);
