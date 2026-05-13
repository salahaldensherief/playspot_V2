import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/art_core/widgets/text_field/app_text_field.dart';
import 'package:playspot/features/auth/presetation/signup/widgets/signup_form.dart';
import 'package:playspot/features/auth/presetation/widgets/social_buttons.dart';

import '../../../../art_core/router/router_keys.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../widgets/auth_app_bar.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            AuthAppBar(
              title: AppStrings.createAnAcc.tr(),
              subTitle: AppStrings.signUpSubtitle.tr(),
            ),
            SizedBox(height: 180.h),
            SocialButtons(),
            _space(),
            Padding(
              padding:  EdgeInsets.symmetric(horizontal: 16.0.w),
              child: SignUpForm(),
            ),
            _space(),
            Padding(
              padding:  EdgeInsets.symmetric(horizontal: 16.0.w),
              child: AppButton(
                buttonConfig: ButtonConfig.gradient(
                  gradient: LinearGradient(
                    colors: const [Color(0xFF00D4FF), Color(0xFF9B59B6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  glowColor: const Color(0xFF00D4FF),
                  borderRadius: 15.r,
                  width: 340.w,
                  height: 50.h,
                ),
                content: ButtonContent(
                  label: AppStrings.createAcc.tr(),

                ),
                behavior: TapBehavior(
                  onTap: () {},
                    isEnabled: true),
              ),
            ),
            _space(),
            AppText(
              color: AppColors.white,
                onTap: (){
                  context.goNamed(RouterKeys.signIn);
                },
                text: AppStrings.alreadyHaveAccount.tr())
          ],
        ),
      ),
    );
  }
}

Widget _space({double? height}) {
  return SizedBox(height: height ?? 20.0);
}
