import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../art_core/app_strings.dart';
import '../../../../../art_core/widgets/text_field/app_text_field.dart';

class SignInForm extends StatelessWidget {
  const SignInForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

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