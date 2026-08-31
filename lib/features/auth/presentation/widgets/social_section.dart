import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../signin_cubit.dart';
import '../signin_state.dart';
import 'social_buttons.dart';

class SocialSection extends StatelessWidget {
  const SocialSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SignInCubit, LoginState, bool>(
      selector: (state) => state.status.isLoading,
      builder: (context, isLoading) {
        final cubit = context.read<SignInCubit>();
        return SocialButtons(
          googleOnTap: isLoading ? null : cubit.signInWithGoogle,
          facebookOnTap: isLoading ? null : cubit.signInWithFacebook,
        );
      },
    );
  }
}
