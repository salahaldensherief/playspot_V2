import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/theme/app_sizes.dart';
import '../../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../signup_cubit.dart';
import '../signup_state.dart';

class SignupButton extends StatelessWidget {
  const SignupButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SignupCubit, SignupState, bool>(
      selector: (state) => state.status == SignupStatus.loading,
      builder: (context, isLoading) {
        final cubit = context.read<SignupCubit>();
        return AppButton(
          buttonConfig: ButtonConfig.gradient(
            gradient: AppColors.primaryGradient,
            glowColor: AppColors.neonBlue,
            borderRadius: AppSizes.r15,
            width: double.infinity,
            height: 50.h,
          ),
          content: ButtonContent(
            label: AppStrings.createAcc.tr(),
          ),
          behavior: TapBehavior(
            isEnabled: !isLoading,
            isLoading: isLoading,
            onTap: () {
              if (cubit.formKey.currentState?.validate() ?? false) {
                cubit.signUpWithEmail();
              }
            },
          ),
        );
      },
    );
  }
}
