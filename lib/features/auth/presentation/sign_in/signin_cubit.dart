import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'signin_state.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../../core/notifications/push_notification_service.dart';

class SignInCubit extends Cubit<LoginState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  SignInCubit(this._authRepository, this._profileRepository) : super(LoginState.init());

  Future<void> _onLoginSuccess() async {
    final token = await PushNotificationService.instance.getToken();
    if (token != null) {
      await _profileRepository.updateFcmToken(token);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(status: LoginStatus.loading));

    final result = await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: failure.message,
      )),
      (user) async {
        await _onLoginSuccess();
        emit(state.copyWith(
          status: LoginStatus.success,
          params: user,
        ));
      },
    );
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(status: LoginStatus.loading));

    final result = await _authRepository.signInWithGoogle();

    result.fold(
      (failure) => emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: failure.message,
      )),
      (user) async {
        if (!user.isNewUser) await _onLoginSuccess();
        emit(state.copyWith(
          status: user.isNewUser
              ? LoginStatus.successSocial
              : LoginStatus.success,
          params: user,
        ));
      },
    );
  }

  Future<void> signInWithFacebook() async {
    emit(state.copyWith(status: LoginStatus.loading));

    final result = await _authRepository.signInWithFacebook();

    result.fold(
      (failure) => emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: failure.message,
      )),
      (user) async {
        if (!user.isNewUser) await _onLoginSuccess();
        emit(state.copyWith(
          status: user.isNewUser
              ? LoginStatus.successSocial
              : LoginStatus.success,
          params: user,
        ));
      },
    );
  }

  void reset() => emit(LoginState.init());

  @override
  Future<void> close() {
    emailController.dispose();
    passwordController.dispose();
    return super.close();
  }
}