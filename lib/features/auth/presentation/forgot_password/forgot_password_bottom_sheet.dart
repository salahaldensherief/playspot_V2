import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/layout/app_bottom_sheet.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/art_core/widgets/otp/app_otp_field.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/core/utils/app_validators.dart';

import 'forgot_password_cubit.dart';
import 'forgot_password_state.dart';

void showForgotPasswordBottomSheet(BuildContext context) {
  AppBottomSheet.show(
    context: context,
    child: BlocProvider(
      create: (context) => sl<ForgotPasswordCubit>(),
      child: const ForgotPasswordBottomSheetContent(),
    ),
  );
}

class ForgotPasswordBottomSheetContent extends StatelessWidget {
  const ForgotPasswordBottomSheetContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ForgotPasswordCubit>();
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, bottomPadding + 20.h),
      child: BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status.isSuccess) {
            GameHudToast.show(
              context,
              AppStrings.passwordResetSuccess.tr(),
              type: ToastType.success,
            );
            Navigator.pop(context);
          } else if (state.status.isFailure) {
            GameHudToast.show(
              context,
              state.errorMessage ?? AppStrings.somethingWentWrong.tr(),
              type: ToastType.error,
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                10.verticalSpace,
                Text(
                  _getTitle(state.status),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                8.verticalSpace,
                Text(
                  _getSubTitle(state.status),
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14.sp,
                  ),
                ),
                24.verticalSpace,
                _buildBody(context, cubit, state),
                20.verticalSpace,
              ],
            ),
          );
        },
      ),
    );
  }

  String _getTitle(ForgotPasswordStatus status) {
    switch (status) {
      case ForgotPasswordStatus.emailSent:
        return AppStrings.verifyOTP.tr();
      case ForgotPasswordStatus.otpVerified:
        return AppStrings.resetPassword.tr();
      default:
        return AppStrings.forgotPassword.tr();
    }
  }

  String _getSubTitle(ForgotPasswordStatus status) {
    switch (status) {
      case ForgotPasswordStatus.emailSent:
        return AppStrings.otpVerificationSubtitle.tr();
      case ForgotPasswordStatus.otpVerified:
        return AppStrings.resetPasswordSubtitle.tr();
      default:
        return AppStrings.forgotPasswordSubtitle.tr();
    }
  }

  Widget _buildBody(BuildContext context, ForgotPasswordCubit cubit, ForgotPasswordState state) {
    final isLoading = state.status.isLoading;

    if (state.status == ForgotPasswordStatus.emailSent) {
      return Column(
        children: [
          AppOtpField(
            controller: cubit.otpController,
            length: 6,
            onCompleted: (otp) {
              cubit.verifyOTP();
            },
          ),
          30.verticalSpace,
          AppButton(
            buttonConfig: ButtonConfig.gradient(
              gradient: AppColors.primaryGradient,
              glowColor: AppColors.neonBlueAlt,
              borderRadius: 15.r,
              width: double.infinity,
              height: 50.h,
            ),
            content: ButtonContent(label: AppStrings.verifyOTP.tr()),
            behavior: TapBehavior(
              isLoading: isLoading,
              onTap: () {
                if (cubit.otpController.text.trim().length == 6) {
                  cubit.verifyOTP();
                }
              },
            ),
          ),
        ],
      );
    }

    if (state.status == ForgotPasswordStatus.otpVerified) {
      return Form(
        key: cubit.resetFormKey,
        child: Column(
          children: [
            AppTextField(
              controller: cubit.passwordController,
              hint: AppStrings.newPassword.tr(),
              isPassword: true,
              validator: AppValidators.validatePassword,
            ),
            16.verticalSpace,
            AppTextField(
              controller: cubit.confirmPasswordController,
              hint: AppStrings.confirmPassword.tr(),
              isPassword: true,
              validator: (val) => AppValidators.validateConfirmPassword(
                val,
                cubit.passwordController.text,
              ),
            ),
            30.verticalSpace,
            AppButton(
              buttonConfig: ButtonConfig.gradient(
                gradient: AppColors.primaryGradient,
                glowColor: AppColors.neonBlueAlt,
                borderRadius: 15.r,
                width: double.infinity,
                height: 50.h,
              ),
              content: ButtonContent(label: AppStrings.resetPassword.tr()),
              behavior: TapBehavior(
                isLoading: isLoading,
                onTap: () {
                  if (cubit.resetFormKey.currentState?.validate() ?? false) {
                    cubit.resetPassword();
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    // Default: Email Input
    return Form(
      key: cubit.forgotFormKey,
      child: Column(
        children: [
          AppTextField(
            controller: cubit.emailController,
            hint: AppStrings.email.tr(),
            textInputType: TextInputType.emailAddress,
            validator: AppValidators.validateEmail,
          ),
          30.verticalSpace,
          AppButton(
            buttonConfig: ButtonConfig.gradient(
              gradient: AppColors.primaryGradient,
              glowColor: AppColors.neonBlueAlt,
              borderRadius: 15.r,
              width: double.infinity,
              height: 50.h,
            ),
            content: ButtonContent(label: AppStrings.sendResetLink.tr()),
            behavior: TapBehavior(
              isLoading: isLoading,
              onTap: () {
                if (cubit.forgotFormKey.currentState?.validate() ?? false) {
                  cubit.sendResetEmail();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
