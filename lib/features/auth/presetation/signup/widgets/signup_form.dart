import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/features/auth/presetation/signup/signup_cubit.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../../art_core/widgets/text_field/app_text_field.dart';

class SignUpForm extends StatelessWidget {
  final SignupCubit cubit;
  const SignUpForm({
    super.key, required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(
          contentPadding: EdgeInsets.all(4),

          label: AppStrings.name.tr(),
          isRequired: true,
          textInputType: TextInputType.name,
          hint: AppStrings.pleaseEnterUsername.tr(),
        ),
        _space(),

        AppTextField(
          contentPadding: EdgeInsets.all(4),
          textInputType: TextInputType.emailAddress,
          label: AppStrings.email.tr(),
          isRequired: true,
          hint: AppStrings.pleaseEnterEmail.tr(),
        ),
        _space(),
        AppTextField(
          contentPadding: EdgeInsets.all(4),

          label: AppStrings.phone.tr(),
          isRequired: true,
          textInputType: TextInputType.phone,
          hint: AppStrings.pleaseEnterPhoneNum.tr(),
        ),
        _space(),
        AppTextField(
          contentPadding: EdgeInsets.all(4),
          label: AppStrings.password.tr(),
          hint: AppStrings.pleaseEnterPassword.tr(),
          isPassword: true,
          isRequired: true,
          textInputType: TextInputType.visiblePassword,
        ),
        _space(),
      ],
    );
  }
}
Widget _space({double? height}) {
  return SizedBox(height: height ?? 10.0);
}