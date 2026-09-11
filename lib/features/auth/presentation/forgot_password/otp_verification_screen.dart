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
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/otp/app_otp_field.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import '../widgets/auth_app_bar.dart';

import 'forgot_password_cubit.dart';
import 'forgot_password_state.dart';
import '../sign_up/signup_cubit.dart';
import '../sign_up/signup_state.dart';

class OTPVerificationScreen extends StatefulWidget {
  final bool isSignUp;

  const OTPVerificationScreen({
    super.key,
    this.isSignUp = false,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  late final TextEditingController _signupOtpController;

  @override
  void initState() {
    super.initState();
    if (widget.isSignUp) {
      _signupOtpController = TextEditingController();
    }
  }

  @override
  void dispose() {
    if (widget.isSignUp) {
      _signupOtpController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSignUp) {
      return _buildSignUpOtpListener(context);
    }
    return _buildForgotPasswordOtpListener(context);
  }

  Widget _buildSignUpOtpListener(BuildContext context) {
    final cubit = context.read<SignupCubit>();
    return BlocListener<SignupCubit, SignupState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status.isSuccess) {
          context.goNamed(RouterKeys.home);
        }
        if (state.status.isFailure) {
          GameHudToast.show(
            context,
            state.errorMessage ?? AppStrings.somethingWentWrong.tr(),
            type: ToastType.error,
          );
        }
      },
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              AuthAppBar(
                title: AppStrings.verifyOTP.tr(),
                subTitle: AppStrings.otpVerificationSubtitle.tr(),
              ),
              250.verticalSpace,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: AppOtpField(
                  controller: _signupOtpController,
                  length: 6,
                  onCompleted: (otp) {
                    cubit.verifySignupOTP(otp);
                  },
                ),
              ),
              40.verticalSpace,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: BlocBuilder<SignupCubit, SignupState>(
                  buildWhen: (previous, current) => previous.status != current.status,
                  builder: (context, state) {
                    return AppButton(
                      buttonConfig: ButtonConfig.gradient(
                        gradient: AppColors.primaryGradient,
                        glowColor: AppColors.neonBlueAlt,
                        borderRadius: 15.r,
                        width: double.infinity,
                        height: 50.h,
                      ),
                      content: ButtonContent(label: AppStrings.verifyOTP.tr()),
                      behavior: TapBehavior(
                        isLoading: state.status.isLoading,
                        onTap: () {
                          if (_signupOtpController.text.trim().isNotEmpty) {
                            cubit.verifySignupOTP(_signupOtpController.text.trim());
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              20.verticalSpace,
              AppText(
                text: AppStrings.resendOTP.tr(),
                color: AppColors.white,
                onTap: () {
                  cubit.resendSignupOTP();
                  GameHudToast.show(
                    context,
                    AppStrings.otpSentTo.tr(),
                    type: ToastType.info,
                  );
                },
              ),
              const SafeBottomSpacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordOtpListener(BuildContext context) {
    final cubit = context.read<ForgotPasswordCubit>();
    return BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status.isOtpVerified) {
          context.goNamed(RouterKeys.resetPassword);
        }
        if (state.status.isFailure) {
          GameHudToast.show(
            context,
            state.errorMessage ?? AppStrings.somethingWentWrong.tr(),
            type: ToastType.error,
          );
        }
      },
      child: Scaffold(
        body: SingleChildScrollView(
          child: Form(
            key: cubit.otpFormKey,
            child: Column(
              children: [
                AuthAppBar(
                  title: AppStrings.verifyOTP.tr(),
                  subTitle: AppStrings.otpVerificationSubtitle.tr(),
                ),
                250.verticalSpace,
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: AppOtpField(
                    controller: cubit.otpController,
                    length: 6,
                    onCompleted: (otp) {
                      cubit.verifyOTP();
                    },
                  ),
                ),
                40.verticalSpace,
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                    buildWhen: (previous, current) => previous.status != current.status,
                    builder: (context, state) {
                      return AppButton(
                        buttonConfig: ButtonConfig.gradient(
                          gradient: AppColors.primaryGradient,
                          glowColor: AppColors.neonBlueAlt,
                          borderRadius: 15.r,
                          width: double.infinity,
                          height: 50.h,
                        ),
                        content: ButtonContent(label: AppStrings.verifyOTP.tr()),
                        behavior: TapBehavior(
                          isLoading: state.status.isLoading,
                          onTap: () {
                            if (cubit.otpFormKey.currentState?.validate() ?? false) {
                              cubit.verifyOTP();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                20.verticalSpace,
                AppText(
                  text: AppStrings.resendOTP.tr(),
                  color: AppColors.white,
                  onTap: () => cubit.sendResetEmail(),
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
