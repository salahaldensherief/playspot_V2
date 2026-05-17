

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
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
import '../../data/repos/auth_repos.dart';
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
    return BlocConsumer<SignupCubit, SignupState>(
      listener: (context, state) {
        if (state.status == SignupStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage.toString())),
          );
        }

        if (state.status == SignupStatus.success) {
          context.goNamed(RouterKeys.home);
        }

        if (state.status == SignupStatus.successSocial) {
          context.goNamed(RouterKeys.completeProfile);
        }
      },
      builder: (context, state) {
        final cubit = context.read<SignupCubit>();

        return Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                AuthAppBar(
                  title: AppStrings.createAnAcc.tr(),
                  subTitle: AppStrings.signUpSubtitle.tr(),
                ),

                SizedBox(height: 180.h),

                SocialButtons(
                  googleOnTap: cubit.signUpWithGoogle,
                  facebookOnTap: cubit.signUpWithFacebook,
                ),

                _space(),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: SignUpForm(cubit: cubit),
                ),

                _space(),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: AppButton(
                    buttonConfig: ButtonConfig.gradient(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00D4FF),
                          Color(0xFF9B59B6),
                        ],
                      ),
                      glowColor: const Color(0xFF00D4FF),
                      borderRadius: 15.r,
                      width: 340.w,
                      height: 50.h,
                    ),
                    content: ButtonContent(
                      label: state.status == SignupStatus.loading
                          ? "Loading..."
                          : AppStrings.createAcc.tr(),
                    ),
                    behavior: TapBehavior(
                      isEnabled: state.status != SignupStatus.loading,
                      onTap: cubit.signUpWithEmail,
                    ),
                  ),
                ),

                _space(),

                AppText(
                  color: AppColors.white,
                  onTap: () {
                    context.goNamed(RouterKeys.signIn);
                  },
                  text: AppStrings.alreadyHaveAccount.tr(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
Widget _space({double? height}) {
  return SizedBox(height: height ?? 20.0);
}