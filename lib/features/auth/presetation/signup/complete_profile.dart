import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/widgets/avatar_picker/avatar_picker_widget.dart';
import 'package:playspot/core/utils/app_validators.dart';

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

class CompleteProfileScreen extends StatefulWidget {
  final String userId;

  const CompleteProfileScreen({super.key, required this.userId});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late final SignupCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<SignupCubit>()..setUserId(widget.userId);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<SignupCubit, SignupState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
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
        },
        buildWhen: (previous, current) =>
        previous.status != current.status ||
            previous.params.avatarUrl != current.params.avatarUrl,
        builder: (context, state) {
          final isLoading = state.status == SignupStatus.loading;
          return Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Form(
                  key: _cubit.formKey,
                  child: Column(
                    children: [
                      AuthAppBar(
                        title: AppStrings.completeProfile.tr(),
                        subTitle: AppStrings.completeProfileSubtitle.tr(),
                      ),
                      SizedBox(height: 200.h),

                      AvatarPickerWidget(
                        avatarFile: _cubit.avatarFile,
                        onTap: _cubit.pickAvatar,
                      ),

                      SizedBox(height: 40.h),

                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: AppTextField(
                          controller: _cubit.phoneController,
                          label: AppStrings.phone.tr(),
                          isRequired: true,
                          textInputType: TextInputType.phone,
                          hint: AppStrings.pleaseEnterPhoneNum.tr(),
                          validator: AppValidators.validatePhone,
                        ),
                      ),

                      SizedBox(height: 30.h),

                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: AppButton(
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
                            onTap: () {
                              if (_cubit.formKey.currentState?.validate() ?? false) {
                                _cubit.completeProfile();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}