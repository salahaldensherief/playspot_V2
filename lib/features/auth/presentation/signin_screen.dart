import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/theme/app_sizes.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/features/auth/presentation/signin_cubit.dart';
import 'package:playspot/features/auth/presentation/signin_state.dart';
import 'package:playspot/features/auth/presentation/widgets/signin_form.dart';
import 'package:playspot/features/auth/presentation/widgets/social_section.dart';
import 'package:playspot/features/auth/presentation/widgets/signin_button.dart';

import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import 'widgets/auth_app_bar.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignInCubit, LoginState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _handleStateChange,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              AuthAppBar(
                title: AppStrings.signIn.tr(),
                subTitle: AppStrings.signInSubtitle.tr(),
              ),
              180.verticalSpace,
              const SocialSection(),
              20.verticalSpace,
              Padding(
                padding: 16.horizontalPadding,
                child: const SignInForm(),
              ),
              20.verticalSpace,
              Padding(
                padding: 16.horizontalPadding,
                child: const SignInButton(),
              ),
              20.verticalSpace,
              AppText(
                color: AppColors.white,
                onTap: () => context.goNamed(RouterKeys.signUp),
                text: AppStrings.dontHaveAccount.tr(),
              ),
              const SafeBottomSpacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, LoginState state) {
    if (state.status.isSuccess) {
      context.goNamed(RouterKeys.home);
    }
    if (state.status.isSuccessSocial) {
      if (state.params.isNewUser) {
        context.goNamed(RouterKeys.completeProfile, extra: state.params.id);
      } else {
        context.goNamed(RouterKeys.home);
      }
      return;
    }
    if (state.status.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? AppStrings.somethingWentWrong.tr()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
