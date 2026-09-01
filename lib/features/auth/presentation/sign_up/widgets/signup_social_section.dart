import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../signup_cubit.dart';
import '../../widgets/social_buttons.dart';

class SignupSocialSection extends StatelessWidget {
  const SignupSocialSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignupCubit>();
    return SocialButtons(
      googleOnTap: cubit.signUpWithGoogle,
      facebookOnTap: cubit.signUpWithFacebook,
    );
  }
}
