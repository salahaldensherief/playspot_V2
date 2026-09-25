import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/auth/data/models/auth_params.dart';
import 'package:playspot/features/auth/data/models/user_model.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/notifications/push_notification_service.dart';
import '../../domain/repositories/auth_repository.dart';
import 'signup_state.dart';

class SignupCubit extends Cubit<SignupState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController referralCodeController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  File? avatarFile;

  SignupCubit(this._authRepository, this._profileRepository)
    : super(SignupState.init()) {
    try {
      final pendingCode = sl<PreferenceManager>().getPendingReferralCode();
      if (pendingCode.isNotEmpty) {
        referralCodeController.text = pendingCode;
      }
    } catch (_) {}
  }

  Future<void> _onSignupSuccess() async {
    final token = await PushNotificationService.instance.getToken();
    if (token != null) {
      await _profileRepository.updateFcmToken(token);
    }
    // Attempt claiming pending referral code after successful sign up and login
    await sl<ProfileCubit>().claimPendingReferralCode();
    unawaited(_updateLocationAfterAuth());
  }

  Future<void> _updateLocationAfterAuth() async {
    try {
      for (int i = 0; i < 5; i++) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;
        try {
          final res = await Supabase.instance.client
              .from('profiles')
              .select('id')
              .eq('id', user.id)
              .maybeSingle();
          if (res != null) {
            await _profileRepository.updateUserLocation();
            break;
          }
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      debugPrint('Background location update error after signup: $e');
    }
  }

  void setUserId(String id) {
    if (isClosed) return;
    emit(state.copyWith(params: state.params.copyWith(id: id)));
  }

  void initWithUser(UserModel? user, {String? userId}) {
    if (isClosed) return;
    final targetId = (userId != null && userId.isNotEmpty)
        ? userId
        : (user?.id ?? state.params.id);
    final avatarUrl = user?.avatarUrl ?? state.params.avatarUrl;
    final phone = user?.phone ?? state.params.phone;
    if (phone != null && phone.isNotEmpty && phoneController.text.isEmpty) {
      phoneController.text = phone;
    }
    emit(
      state.copyWith(
        params: state.params.copyWith(id: targetId, avatarUrl: avatarUrl),
      ),
    );
  }

  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null && !isClosed) {
      final file = File(picked.path);
      final length = await file.length();
      if (length > 2 * 1024 * 1024) {
        emit(
          state.copyWith(
            status: SignupStatus.failure,
            errorMessage: 'Avatar image must be under 2MB',
          ),
        );
        return;
      }
      avatarFile = file;
      emit(
        state.copyWith(params: state.params.copyWith(avatarUrl: picked.path)),
      );
    }
  }

  Future<void> signUpWithEmail() async {
    AppLogger.debug("SIGNUP_CUBIT: Signing up with email");
    if (isClosed) return;

    final enteredCode = referralCodeController.text.trim();
    if (enteredCode.isNotEmpty) {
      await sl<PreferenceManager>().savePendingReferralCode(enteredCode);
    }

    emit(state.copyWith(status: SignupStatus.loading));

    final result = await _authRepository.signUpWithEmail(
      SignUpParams(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        avatarFile: avatarFile,
        referralCode: enteredCode,
      ),
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        AppLogger.error("SIGNUP_CUBIT_ERROR: ${failure.message}");
        if (!isClosed) {
          emit(
            state.copyWith(
              status: SignupStatus.failure,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (user) async {
        AppLogger.debug(
          "SIGNUP_CUBIT: Signup result for user, isRequiresOtp: ${user.isRequiresOtp}",
        );
        if (user.isRequiresOtp) {
          if (!isClosed) {
            emit(
              state.copyWith(status: SignupStatus.requiresOtp, params: user),
            );
          }
        } else {
          await _onSignupSuccess();
          if (!isClosed) {
            emit(state.copyWith(status: SignupStatus.success, params: user));
          }
        }
      },
    );
  }

  Future<void> verifySignupOTP(String otp) async {
    AppLogger.debug("SIGNUP_CUBIT: Verifying signup OTP");
    if (isClosed) return;
    emit(state.copyWith(status: SignupStatus.loading));

    final emailToUse = emailController.text.trim().isNotEmpty
        ? emailController.text.trim()
        : (state.params.email ?? '');

    final result = await _authRepository.verifySignupOTP(
      email: emailToUse,
      otp: otp.trim(),
      params: SignUpParams(
        email: emailToUse,
        password: passwordController.text.trim(),
        name: nameController.text.trim().isNotEmpty
            ? nameController.text.trim()
            : (state.params.name ?? ''),
        phone: phoneController.text.trim().isNotEmpty
            ? phoneController.text.trim()
            : (state.params.phone ?? ''),
        avatarFile: avatarFile,
        referralCode: referralCodeController.text.trim(),
      ),
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        AppLogger.error("SIGNUP_CUBIT_ERROR (OTP): ${failure.message}");
        if (!isClosed) {
          emit(
            state.copyWith(
              status: SignupStatus.failure,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (user) async {
        AppLogger.debug("SIGNUP_CUBIT: OTP verification success");
        await _onSignupSuccess();
        if (!isClosed) {
          emit(state.copyWith(status: SignupStatus.success, params: user));
        }
      },
    );
  }

  Future<void> resendSignupOTP() async {
    final email = emailController.text.trim().isNotEmpty
        ? emailController.text.trim()
        : (state.params.email ?? '');
    AppLogger.debug("SIGNUP_CUBIT: Resending signup OTP");
    if (email.isEmpty) return;

    final result = await _authRepository.resendSignupOTP(email);
    result.fold(
      (failure) {
        AppLogger.error("SIGNUP_CUBIT_ERROR (Resend OTP): ${failure.message}");
        if (!isClosed) {
          emit(
            state.copyWith(
              status: SignupStatus.failure,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (_) {
        AppLogger.debug("SIGNUP_CUBIT: Resent signup OTP successfully");
      },
    );
  }

  Future<void> signUpWithGoogle() async {
    AppLogger.debug("SIGNUP_CUBIT: Signing up with Google");
    if (isClosed) return;
    emit(state.copyWith(status: SignupStatus.loading));

    final result = await _authRepository.signInWithGoogle();

    if (isClosed) return;

    result.fold(
      (failure) {
        if (isClosed) return;
        if (failure.message.contains('cancelled') ||
            failure.message.contains('GoogleSignInCancelledException')) {
          emit(state.copyWith(status: SignupStatus.initial));
        } else {
          AppLogger.error("SIGNUP_CUBIT_ERROR (Google): ${failure.message}");
          emit(
            state.copyWith(
              status: SignupStatus.failure,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (user) async {
        AppLogger.debug(
          "SIGNUP_CUBIT: Google sign-in success. isNewUser: ${user.isNewUser}",
        );
        if (!user.isNewUser) await _onSignupSuccess();
        if (!isClosed) {
          emit(
            state.copyWith(
              status: user.isNewUser
                  ? SignupStatus.successSocial
                  : SignupStatus.success,
              params: user,
            ),
          );
        }
      },
    );
  }

  Future<void> signUpWithFacebook() async {
    AppLogger.debug("SIGNUP_CUBIT: Signing up with Facebook");
    if (isClosed) return;
    emit(state.copyWith(status: SignupStatus.loading));

    final result = await _authRepository.signInWithFacebook();

    if (isClosed) return;

    result.fold(
      (failure) {
        if (isClosed) return;
        AppLogger.error("SIGNUP_CUBIT_ERROR (Facebook): ${failure.message}");
        emit(
          state.copyWith(
            status: SignupStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
      (user) async {
        AppLogger.debug(
          "SIGNUP_CUBIT: Facebook sign-in success. isNewUser: ${user.isNewUser}",
        );
        if (!user.isNewUser) await _onSignupSuccess();
        if (!isClosed) {
          emit(
            state.copyWith(
              status: user.isNewUser
                  ? SignupStatus.successSocial
                  : SignupStatus.success,
              params: user,
            ),
          );
        }
      },
    );
  }

  Future<void> completeProfile({String? userId}) async {
    final targetUserId = (userId != null && userId.isNotEmpty)
        ? userId
        : state.params.id;
    AppLogger.debug("SIGNUP_CUBIT: Completing profile for user: $targetUserId");
    if (isClosed) return;
    emit(state.copyWith(status: SignupStatus.loading));
    final result = await _authRepository.completeProfile(
      CompleteProfileParams(
        userId: targetUserId,
        phone: phoneController.text.trim(),
        avatarFile: avatarFile,
      ),
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        if (isClosed) return;
        AppLogger.error("SIGNUP_CUBIT_ERROR (Complete): ${failure.message}");
        emit(
          state.copyWith(
            status: SignupStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
      (user) async {
        AppLogger.debug("SIGNUP_CUBIT: Profile completed successfully");
        await _onSignupSuccess();
        if (!isClosed) {
          emit(state.copyWith(status: SignupStatus.success, params: user));
        }
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
    if (!isClosed) {
      emit(SignupState.init());
    }
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
