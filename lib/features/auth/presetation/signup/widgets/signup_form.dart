import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/core/utils/app_validators.dart';
import 'package:playspot/features/auth/presetation/signup/signup_cubit.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/widgets/text_field/app_text_field.dart';

class SignUpForm extends StatelessWidget {
  final SignupCubit cubit;
  const SignUpForm({
    super.key,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: cubit.formKey,
      child: Column(
        children: [
          AppTextField(
            controller: cubit.nameController,
            contentPadding: const EdgeInsets.all(4),
            label: AppStrings.name.tr(),
            isRequired: true,
            textInputType: TextInputType.name,
            hint: AppStrings.pleaseEnterUsername.tr(),
            validator: AppValidators.validateName,
          ),
          _space(),
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
            controller: cubit.phoneController,
            contentPadding: const EdgeInsets.all(4),
            label: AppStrings.phone.tr(),
            isRequired: true,
            textInputType: TextInputType.phone,
            hint: AppStrings.pleaseEnterPhoneNum.tr(),
            validator: AppValidators.validatePhone,
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
          _space(),
        ],
      ),
    );
  }
}

Widget _space({double? height}) {
  return SizedBox(height: height ?? 10.0);
}
