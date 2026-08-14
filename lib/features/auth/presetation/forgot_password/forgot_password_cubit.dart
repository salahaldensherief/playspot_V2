import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/auth/data/repos/auth_repo.dart';
import 'forgot_password_state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  final AuthRepository _authRepository;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  final GlobalKey<FormState> forgotFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> otpFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> resetFormKey = GlobalKey<FormState>();

  ForgotPasswordCubit(this._authRepository) : super(ForgotPasswordState.initial());

  Future<void> sendResetEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;

    emit(state.copyWith(status: ForgotPasswordStatus.loading));

    final result = await _authRepository.sendPasswordResetEmail(email);

    result.fold(
      (failure) => emit(state.copyWith(
        status: ForgotPasswordStatus.failure,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: ForgotPasswordStatus.emailSent,
        email: email,
      )),
    );
  }

  Future<void> verifyOTP() async {
    final otp = otpController.text.trim();
    if (otp.isEmpty || state.email == null) return;

    emit(state.copyWith(status: ForgotPasswordStatus.loading));

    final result = await _authRepository.verifyPasswordResetOTP(
      email: state.email!,
      otp: otp,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: ForgotPasswordStatus.failure,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: ForgotPasswordStatus.otpVerified,
      )),
    );
  }

  Future<void> resetPassword() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password.isEmpty || password != confirmPassword) {
      emit(state.copyWith(
        status: ForgotPasswordStatus.failure,
        errorMessage: "Passwords don't match",
      ));
      return;
    }

    emit(state.copyWith(status: ForgotPasswordStatus.loading));

    final result = await _authRepository.resetPassword(password);

    result.fold(
      (failure) => emit(state.copyWith(
        status: ForgotPasswordStatus.failure,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: ForgotPasswordStatus.success,
      )),
    );
  }

  @override
  Future<void> close() {
    emailController.dispose();
    otpController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    return super.close();
  }
}
