import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import '../profile_cubit.dart';
import '../profile_state.dart';

class ProfileLogoutListener extends StatelessWidget {
  final Widget child;
  const ProfileLogoutListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      BlocListener<ProfileCubit, ProfileState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            (current.status == ProfileStatus.logoutSuccess ||
                (previous.status == ProfileStatus.loggingOut &&
                    current.status == ProfileStatus.error)),
        listener: (context, state) {
          if (state.status == ProfileStatus.logoutSuccess) {
            context.goNamed(RouterKeys.signIn);
          } else {
            GameHudToast.show(
              context,
              (state.errorMessage ?? AppStrings.somethingWentWrong).tr(
                context: context,
              ),
              type: ToastType.error,
            );
          }
        },
        child: child,
      );
}
