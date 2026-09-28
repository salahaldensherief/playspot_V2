import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/core/utils/app_validators.dart';
import '../signup_cubit.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/widgets/text_field/app_text_field.dart';

class SignUpForm extends StatelessWidget {
  final SignupCubit? cubit;
  const SignUpForm({
    super.key,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    final activeCubit = cubit ?? context.read<SignupCubit>();
    return Form(
      key: activeCubit.formKey,
      child: Column(
        children: [
          AppTextField(
            controller: activeCubit.nameController,
            label: AppStrings.name.tr(),
            isRequired: true,
            textInputType: TextInputType.name,
            hint: AppStrings.pleaseEnterUsername.tr(),
            validator: AppValidators.validateName,
          ),
          10.verticalSpace,
          AppTextField(
            controller: activeCubit.emailController,
            textInputType: TextInputType.emailAddress,
            label: AppStrings.email.tr(),
            isRequired: true,
            hint: AppStrings.pleaseEnterEmail.tr(),
            validator: AppValidators.validateEmail,
          ),
          10.verticalSpace,
          AppTextField(
            controller: activeCubit.phoneController,
            label: AppStrings.phone.tr(),
            isRequired: true,
            textInputType: TextInputType.phone,
            hint: AppStrings.pleaseEnterPhoneNum.tr(),
            validator: AppValidators.validatePhone,
          ),
          10.verticalSpace,
          AppTextField(
            controller: activeCubit.passwordController,
            label: AppStrings.password.tr(),
            hint: AppStrings.pleaseEnterPassword.tr(),
            isPassword: true,
            isRequired: true,
            textInputType: TextInputType.visiblePassword,
            validator: AppValidators.validatePassword,
          ),
          10.verticalSpace,
          AppTextField(
            controller: activeCubit.referralCodeController,
            label: AppStrings.referralCodeOptional.tr(),
            hint: AppStrings.referralCodeHint.tr(),
            textInputType: TextInputType.text,
          ),
          10.verticalSpace,
        ],
      ),
    );
  }
}
