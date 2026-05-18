import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/auth/presetation/signin/signin_state.dart';

import '../../data/repos/auth_repos.dart';


class LoginCubit extends Cubit<LoginState> {
  final AuthRepository _authRepository;

  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginCubit(this._authRepository) : super(LoginState.init());

  // ─── Email Sign In ────────────────────────────────────────────
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
          (error) => emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: error,
      )),
          (user) => emit(state.copyWith(
        status: LoginStatus.success,
        params: user,
      )),
    );
  }

  // ─── Google Sign In ───────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    emit(state.copyWith(status: LoginStatus.loading));

    final result = await _authRepository.signInWithGoogle();

    result.fold(
          (error) => emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: error,
      )),
          (user) => emit(state.copyWith(
        status: user.isNewUser
            ? LoginStatus.successSocial
            : LoginStatus.success,
        params: user,
      )),
    );
  }

  // ─── Facebook Sign In ─────────────────────────────────────────
  Future<void> signInWithFacebook() async {
    emit(state.copyWith(status: LoginStatus.loading));

    final result = await _authRepository.signInWithFacebook();

    result.fold(
          (error) => emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: error,
      )),
          (user) => emit(state.copyWith(
        status: user.isNewUser
            ? LoginStatus.successSocial
            : LoginStatus.success,
        params: user,
      )),
    );
  }

  // ─── Reset ────────────────────────────────────────────────────
  void reset() => emit(LoginState.init());

  @override
  Future<void> close() {
    emailController.dispose();
    passwordController.dispose();
    return super.close();
  }
}