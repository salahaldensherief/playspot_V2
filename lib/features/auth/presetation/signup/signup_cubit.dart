import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playspot/features/auth/presetation/signup/signup_state.dart';

import '../../data/repos/auth_repos.dart';


class SignupCubit extends Cubit<SignupState> {
  final AuthRepository _authRepository;

  final TextEditingController nameController     = TextEditingController();
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController    = TextEditingController();

  File? avatarFile;

  SignupCubit(this._authRepository) : super(SignupState.init());

  // ─── Set User ID (بعد ما بييجي من الـ Router) ─────────────────
  void setUserId(String id) {
    emit(state.copyWith(
      params: state.params.copyWith(id: id),
    ));
  }

  // ─── Pick Avatar ──────────────────────────────────────────────
  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      avatarFile = File(picked.path);
      emit(state.copyWith(
        params: state.params.copyWith(avatarUrl: picked.path),
      ));
    }
  }

  // ─── Email Sign Up ────────────────────────────────────────────
  Future<void> signUpWithEmail() async {
    emit(state.copyWith(status: SignupStatus.loading));

    final result = await _authRepository.signUpWithEmail(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      avatarFile: avatarFile,
    );

    result.fold(
          (error) => emit(state.copyWith(
        status: SignupStatus.failure,
        errorMessage: error,
      )),
          (user) => emit(state.copyWith(
        status: SignupStatus.success,
        params: user,
      )),
    );
  }

  // ─── Google Sign Up ───────────────────────────────────────────
  Future<void> signUpWithGoogle() async {
    emit(state.copyWith(status: SignupStatus.loading));

    final result = await _authRepository.signUpWithGoogle();

    result.fold(
          (error) => emit(state.copyWith(
        status: SignupStatus.failure,
        errorMessage: error,
      )),
          (user) => emit(state.copyWith(
        // لو isNewUser روح Complete Profile، لو مش جديد روح Home
        status: user.isNewUser
            ? SignupStatus.successSocial
            : SignupStatus.success,
        params: user,
      )),
    );
  }

  // ─── Facebook Sign Up ─────────────────────────────────────────
  Future<void> signUpWithFacebook() async {
    emit(state.copyWith(status: SignupStatus.loading));

    final result = await _authRepository.signUpWithFacebook();

    result.fold(
          (error) => emit(state.copyWith(
        status: SignupStatus.failure,
        errorMessage: error,
      )),
          (user) => emit(state.copyWith(
        status: user.isNewUser
            ? SignupStatus.successSocial
            : SignupStatus.success,
        params: user,
      )),
    );
  }

  // ─── Complete Profile ─────────────────────────────────────────
  Future<void> completeProfile() async {
    emit(state.copyWith(status: SignupStatus.loading));

    final result = await _authRepository.completeProfile(
      userId: state.params.id,
      phone: phoneController.text.trim(),
      avatarFile: avatarFile,
    );

    result.fold(
          (error) => emit(state.copyWith(
        status: SignupStatus.failure,
        errorMessage: error,
      )),
          (user) => emit(state.copyWith(
        status: SignupStatus.success,
        params: user,
      )),
    );
  }

  // ─── Reset ────────────────────────────────────────────────────
  void reset() => emit(SignupState.init());

  @override
  Future<void> close() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    return super.close();
  }
}