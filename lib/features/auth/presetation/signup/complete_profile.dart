import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/router/router_keys.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/text_field/app_text_field.dart';
import '../signup/signup_cubit.dart';
import '../signup/signup_state.dart';
import '../widgets/auth_app_bar.dart';

class CompleteProfileScreen extends StatelessWidget {
  const CompleteProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CompleteProfileView();
  }
}

class _CompleteProfileView extends StatelessWidget {
  const _CompleteProfileView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignupCubit>();

    return BlocListener<SignupCubit, SignupState>(
      listener: (context, state) {
        if (state.status == SignupStatus.success) {
          context.goNamed(RouterKeys.home);
        }

        if (state.status == SignupStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage ?? 'Something went wrong',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                AuthAppBar(
                  title: AppStrings.completeProfile.tr(),
                  subTitle: AppStrings.completeProfileSubtitle.tr(),
                ),

                SizedBox(height: 80.h),

                BlocBuilder<SignupCubit, SignupState>(
                  builder: (context, state) {
                    return GestureDetector(
                      onTap: () {
                        cubit.pickAvatar();
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60.r,
                            backgroundColor: AppColors.primary,
                            backgroundImage: cubit.avatarFile != null
                                ? FileImage(cubit.avatarFile!)
                                : null,
                            child: cubit.avatarFile == null
                                ? Icon(
                              Icons.person,
                              size: 60.sp,
                              color: AppColors.white,
                            )
                                : null,
                          ),

                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: AppColors.white,
                              size: 18.sp,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                SizedBox(height: 40.h),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: AppTextField(
                    controller: cubit.phoneController,
                    contentPadding: const EdgeInsets.all(4),
                    label: AppStrings.phone.tr(),
                    isRequired: true,
                    textInputType: TextInputType.phone,
                    hint: AppStrings.pleaseEnterPhoneNum.tr(),
                  ),
                ),

                SizedBox(height: 30.h),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: BlocBuilder<SignupCubit, SignupState>(
                    builder: (context, state) {
                      return AppButton(
                        buttonConfig: ButtonConfig.gradient(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF00D4FF),
                              Color(0xFF9B59B6),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          glowColor: const Color(0xFF00D4FF),
                          borderRadius: 15.r,
                          width: 340.w,
                          height: 50.h,
                        ),

                        content: ButtonContent(
                          label: AppStrings.continueText.tr(),
                        ),

                        behavior: TapBehavior(
                          isEnabled:
                          state.status != SignupStatus.loading,

                          isLoading:
                          state.status == SignupStatus.loading,

                          onTap: () {
                            cubit.completeProfile();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}