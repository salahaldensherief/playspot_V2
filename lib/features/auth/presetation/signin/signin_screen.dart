import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/features/auth/presetation/signin/widgets/signin_form.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../signup/widgets/signup_form.dart';
import '../widgets/auth_app_bar.dart';
import '../widgets/social_buttons.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            AuthAppBar(
              title: AppStrings.signIn.tr(),
              subTitle: AppStrings.signInSubtitle.tr(),
            ),
            SizedBox(height: 180.h),
            SocialButtons(),
            _space(),
            Padding(
              padding:  EdgeInsets.symmetric(horizontal: 16.0.w),
              child: SignInForm(),
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
                  label: AppStrings.signIn.tr(),

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
                  context.goNamed(RouterKeys.signUp);
                },
                text: AppStrings.dontHaveAccount.tr())
          ],
        ),
      ),
    );
  }
}

Widget _space({double? height}) {
  return SizedBox(height: height ?? 20.0);
}
