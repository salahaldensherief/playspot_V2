import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/avatar_picker/avatar_picker_widget.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'package:playspot/core/utils/app_validators.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/router/router_keys.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/text_field/app_text_field.dart';
import 'signup_cubit.dart';
import '../../data/models/user_model.dart';
import 'signup_state.dart';
import '../widgets/auth_app_bar.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String userId;
  final UserModel? initialUser;

  const CompleteProfileScreen({
    super.key,
    required this.userId,
    this.initialUser,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SignupCubit>().initWithUser(widget.initialUser, userId: widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SignupCubit, SignupState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == SignupStatus.success) {
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
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.params.avatarUrl != current.params.avatarUrl,
      builder: (context, state) {
        final cubit = context.read<SignupCubit>();
        final isLoading = state.status == SignupStatus.loading;
        return Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: cubit.formKey,
              child: Column(
                children: [
                  AuthAppBar(
                    title: AppStrings.completeProfile.tr(),
                    subTitle: AppStrings.completeProfileSubtitle.tr(),
                  ),
                  180.verticalSpace,
                  AvatarPickerWidget(
                    avatarFile: cubit.avatarFile,
                    imageUrl: state.params.avatarUrl,
                    onTap: cubit.pickAvatar,
                  ),
                  40.verticalSpace,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: AppTextField(
                      controller: cubit.phoneController,
                      label: AppStrings.phone.tr(),
                      isRequired: true,
                      textInputType: TextInputType.phone,
                      hint: AppStrings.pleaseEnterPhoneNum.tr(),
                      validator: AppValidators.validatePhone,
                    ),
                  ),
                  30.verticalSpace,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: AppButton(
                      buttonConfig: ButtonConfig.gradient(
                        gradient: AppColors.primaryGradient,
                        glowColor: AppColors.neonBlue,
                        borderRadius: 15.r,
                        width: double.infinity,
                        height: 50.h,
                      ),
                      content: ButtonContent(label: AppStrings.continueText.tr()),
                      behavior: TapBehavior(
                        isEnabled: !isLoading,
                        isLoading: isLoading,
                        onTap: () {
                          if (cubit.formKey.currentState?.validate() ?? false) {
                            cubit.completeProfile(userId: widget.userId);
                          }
                        },
                      ),
                    ),
                  ),
                  const SafeBottomSpacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
