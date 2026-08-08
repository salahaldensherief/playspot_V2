import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/core/utils/app_validators.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/features/auth/presetation/widgets/auth_app_bar.dart';

import 'forgot_password_cubit.dart';
import 'forgot_password_state.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ForgotPasswordCubit>();
    return BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
      listener: (context, state) {
        if (state.status.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset successfully'),
              backgroundColor: AppColors.primary,
            ),
          );
          context.goNamed(RouterKeys.signIn);
        }
        if (state.status.isFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Error'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      },
      child: Scaffold(
        body: SingleChildScrollView(
          child: Form(
            key: cubit.resetFormKey,
            child: Column(
              children: [
                AuthAppBar(
                  title: AppStrings.resetPassword.tr(),
                  subTitle: AppStrings.resetPasswordSubtitle.tr(),
                ),
                SizedBox(height: 260.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: AppTextField(

                    controller: cubit.passwordController,
                    hint: AppStrings.newPassword.tr(),
                    isPassword: true,
                    validator: AppValidators.validatePassword,
                  ),
                ),
                SizedBox(height: 20.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: AppTextField(
                    controller: cubit.confirmPasswordController,
                    hint: AppStrings.confirmPassword.tr(),
                    isPassword: true,
                    validator: (val) => AppValidators.validateConfirmPassword(val, cubit.passwordController.text),
                  ),
                ),
                SizedBox(height: 40.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                    builder: (context, state) {
                      return AppButton(
                        buttonConfig: ButtonConfig.gradient(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF9B59B6)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          glowColor: const Color(0xFF00D4FF),
                          borderRadius: 15.r,
                          width: double.infinity,
                          height: 50.h,
                        ),
                        content: ButtonContent(label: AppStrings.resetPassword.tr()),
                        behavior: TapBehavior(
                          isLoading: state.status.isLoading,
                          onTap: () {
                            if (cubit.resetFormKey.currentState?.validate() ?? false) {
                              cubit.resetPassword();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SafeBottomSpacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
