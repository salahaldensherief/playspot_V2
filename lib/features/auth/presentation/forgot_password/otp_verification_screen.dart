import 'dart:async';
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
import '../sign_up/signup_cubit.dart';
import '../sign_up/signup_state.dart';

class OTPVerificationScreen extends StatefulWidget {
  final bool isSignUp;

  const OTPVerificationScreen({
    super.key,
    this.isSignUp = true,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  late final TextEditingController _otpController;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignupCubit>();
    return BlocListener<SignupCubit, SignupState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == SignupStatus.success) {
          GameHudToast.show(
            context,
            AppStrings.accountCreatedVerifyEmail.tr(),
            type: ToastType.success,
          );
          context.goNamed(RouterKeys.home);
        }
        if (state.status == SignupStatus.failure) {
          GameHudToast.show(
            context,
            state.errorMessage ?? AppStrings.somethingWentWrong.tr(),
            type: ToastType.error,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SingleChildScrollView(
          child: Column(
            children: [
              AuthAppBar(
                title: AppStrings.verifyOTP.tr(),
                subTitle: AppStrings.otpVerificationSubtitle.tr(),
              ),
              180.verticalSpace,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: AppOtpField(
                  controller: _otpController,
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
                          if (_otpController.text.trim().isNotEmpty) {
                            cubit.verifySignupOTP(_otpController.text.trim());
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              20.verticalSpace,
              AppText(
                text: _cooldownSeconds > 0
                    ? '${AppStrings.resendOTP.tr()} (${_cooldownSeconds}s)'
                    : AppStrings.resendOTP.tr(),
                color: _cooldownSeconds > 0 ? AppColors.textSecondary : AppColors.white,
                onTap: _cooldownSeconds > 0
                    ? null
                    : () {
                        cubit.resendSignupOTP();
                        _startCooldown();
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
}
