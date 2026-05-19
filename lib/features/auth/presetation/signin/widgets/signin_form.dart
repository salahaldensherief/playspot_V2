import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/core/utils/app_validators.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/theme/app_colors.dart';
import '../../../../../art_core/widgets/text/app_text.dart';
import '../../../../../art_core/widgets/text_field/app_text_field.dart';
import '../signin_cubit.dart';

class SignInForm extends StatelessWidget {
  const SignInForm({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignInCubit>();
    return Form(
      key: cubit.formKey,
      child: Column(
        children: [
          AppTextField(
            controller: cubit.emailController,
            contentPadding: const EdgeInsets.all(4),
            textInputType: TextInputType.emailAddress,
            label: AppStrings.email.tr(),
            isRequired: true,
            hint: AppStrings.pleaseEnterEmail.tr(),
            validator: AppValidators.validateEmail,
          ),
          _space(),
          AppTextField(
            controller: cubit.passwordController,
            contentPadding: const EdgeInsets.all(4),
            label: AppStrings.password.tr(),
            hint: AppStrings.pleaseEnterPassword.tr(),
            isPassword: true,
            isRequired: true,
            textInputType: TextInputType.visiblePassword,
            validator: AppValidators.validatePassword,
          ),
        _space(height: 10.h),
        Align(
          alignment: Alignment.centerRight,
          child: AppText(
            text: AppStrings.forgotPassword.tr(),
            color: AppColors.white,
            onTap: () => context.pushNamed(RouterKeys.forgotPassword),
          ),
        ),
        _space(),
      ],
    ),
        );
  }
}

Widget _space({double? height}) {
  return SizedBox(height: height ?? 10.0);
}
