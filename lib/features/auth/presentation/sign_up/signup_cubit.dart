import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playspot/features/auth/data/models/auth_params.dart';
import 'signup_state.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../../core/notifications/push_notification_service.dart';

class SignupCubit extends Cubit<SignupState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  final TextEditingController nameController     = TextEditingController();
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController    = TextEditingController();
  final TextEditingController referralCodeController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  File? avatarFile;

  SignupCubit(this._authRepository, this._profileRepository) : super(SignupState.init());

  Future<void> _onSignupSuccess() async {
    final token = await PushNotificationService.instance.getToken();
    if (token != null) {
      await _profileRepository.updateFcmToken(token);
    }
  }

  void setUserId(String id) {
    emit(state.copyWith(
      params: state.params.copyWith(id: id),
    ));
  }

  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null) {
      avatarFile = File(picked.path);
      emit(state.copyWith(
        params: state.params.copyWith(avatarUrl: picked.path),
      ));
    }
  }

  Future<void> signUpWithEmail() async {
    log("SIGNUP_CUBIT: Signing up with email: ${emailController.text}");
    emit(state.copyWith(status: SignupStatus.loading));

    final result = await _authRepository.signUpWithEmail(
      SignUpParams(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        avatarFile: avatarFile,
        referralCode: referralCodeController.text.trim(),
      ),
    );

    result.fold(
      (failure) {
        log("SIGNUP_CUBIT_ERROR: ${failure.message}");
        emit(state.copyWith(
          status: SignupStatus.failure,
          errorMessage: failure.message,
        ));
      },
      (user) async {
        log("SIGNUP_CUBIT: Signup success for user: ${user.id}");
        await _onSignupSuccess();
        emit(state.copyWith(
          status: SignupStatus.success,
          params: user,
        ));
      },
    );
  }

  Future<void> signUpWithGoogle() async {
    log("SIGNUP_CUBIT: Signing up with Google");
    emit(state.copyWith(status: SignupStatus.loading));

    final result = await _authRepository.signInWithGoogle();

    result.fold(
      (failure) {
        log("SIGNUP_CUBIT_ERROR (Google): ${failure.message}");
        emit(state.copyWith(
          status: SignupStatus.failure,
          errorMessage: failure.message,
        ));
      },
      (user) async {
        log("SIGNUP_CUBIT: Google sign-in success. isNewUser: ${user.isNewUser}");
        if (!user.isNewUser) await _onSignupSuccess();
        emit(state.copyWith(
          status: user.isNewUser
              ? SignupStatus.successSocial
              : SignupStatus.success,
          params: user,
        ));
      },
    );
  }

  Future<void> signUpWithFacebook() async {
    log("SIGNUP_CUBIT: Signing up with Facebook");
    emit(state.copyWith(status: SignupStatus.loading));

    final result = await _authRepository.signInWithFacebook();

    result.fold(
      (failure) {
        log("SIGNUP_CUBIT_ERROR (Facebook): ${failure.message}");
        emit(state.copyWith(
          status: SignupStatus.failure,
          errorMessage: failure.message,
        ));
      },
      (user) async {
        log("SIGNUP_CUBIT: Facebook sign-in success. isNewUser: ${user.isNewUser}");
        if (!user.isNewUser) await _onSignupSuccess();
        emit(state.copyWith(
          status: user.isNewUser
              ? SignupStatus.successSocial
              : SignupStatus.success,
          params: user,
        ));
      },
    );
  }

  Future<void> completeProfile() async {
    log("SIGNUP_CUBIT: Completing profile for user: ${state.params.id}");
    emit(state.copyWith(status: SignupStatus.loading));
    final result = await _authRepository.completeProfile(
      CompleteProfileParams(
        userId: state.params.id,
        phone: phoneController.text.trim(),
        avatarFile: avatarFile,
      ),
    );

    result.fold(
      (failure) {
        log("SIGNUP_CUBIT_ERROR (Complete): ${failure.message}");
        emit(state.copyWith(
          status: SignupStatus.failure,
          errorMessage: failure.message,
        ));
      },
      (user) async {
        log("SIGNUP_CUBIT: Profile completed successfully");
        await _onSignupSuccess();
        emit(state.copyWith(
          status: SignupStatus.success,
          params: user,
        ));
      },
    );
  }

  void reset() {
    nameController.clear();
    emailController.clear();
    passwordController.clear();
    phoneController.clear();
    referralCodeController.clear();
    avatarFile = null;
    emit(SignupState.init());
  }

  @override
  Future<void> close() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    referralCodeController.dispose();
    return super.close();
  }
}