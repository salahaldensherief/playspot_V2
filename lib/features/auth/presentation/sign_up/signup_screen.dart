import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/utils/extensions/spacing_extensions.dart';
import 'package:playspot/art_core/widgets/layout/safe_bottom_spacer.dart';
import 'package:playspot/art_core/widgets/avatar_picker/avatar_picker_widget.dart';
import 'signup_cubit.dart';
import 'signup_state.dart';
import 'widgets/signup_form.dart';
import 'widgets/signup_social_section.dart';
import 'widgets/signup_button.dart';

import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/text/app_text.dart';
import '../widgets/auth_app_bar.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignupCubit, SignupState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _handleStateChange,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              AuthAppBar(
                title: AppStrings.createAnAcc.tr(),
                subTitle: AppStrings.signUpSubtitle.tr(),
              ),
              180.verticalSpace,
              const SignupSocialSection(),
              20.verticalSpace,
              BlocSelector<SignupCubit, SignupState, String?>(
                selector: (state) => state.params.avatarUrl,
                builder: (context, _) {
                  final cubit = context.read<SignupCubit>();
                  return AvatarPickerWidget(
                    avatarFile: cubit.avatarFile,
                    onTap: cubit.pickAvatar,
                  );
                },
              ),
              20.verticalSpace,
              Padding(
                padding: 16.horizontalPadding,
                child: SignUpForm(cubit: context.read<SignupCubit>()),
              ),
              20.verticalSpace,
              Padding(
                padding: 16.horizontalPadding,
                child: const SignupButton(),
              ),
              20.verticalSpace,
              AppText(
                color: AppColors.white,
                onTap: () => context.goNamed(RouterKeys.signIn),
                text: AppStrings.alreadyHaveAccount.tr(),
              ),
              const SafeBottomSpacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, SignupState state) {
    if (state.status == SignupStatus.success) {
      context.goNamed(RouterKeys.home);
    }

    if (state.status == SignupStatus.successSocial) {
      context.goNamed(
        RouterKeys.completeProfile,
        extra: state.params.id,
      );
    }

    if (state.status == SignupStatus.failure) {
      GameHudToast.show(
        context,
        state.errorMessage ?? AppStrings.somethingWentWrong.tr(),
        type: ToastType.error,
      );
    }
  }
}
