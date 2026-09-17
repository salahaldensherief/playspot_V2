import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/profile/data/models/profile_params.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'edit_profile_state.dart';

class EditProfileCubit extends Cubit<EditProfileState> {
  final ProfileRepository _profileRepository;
  final AuthRepository _authRepository;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  EditProfileCubit(this._profileRepository, this._authRepository) : super(const EditProfileState());

  Future<void> init() async {
    final currentUser = _profileRepository.getCurrentUser();
    nameController.text = currentUser?.name ?? '';
    phoneController.text = currentUser?.phone ?? '';
    emailController.text = currentUser?.email ?? '';
    locationController.text = currentUser?.getCityName(true) ?? (currentUser?.getCityName(false) ?? '');

    emit(state.copyWith(user: currentUser));

    // Fetch full profile
    final profileRes = await _profileRepository.getUserProfile();
    profileRes.fold(
      (_) {},
      (user) {
        nameController.text = user.name ?? nameController.text;
        phoneController.text = user.phone ?? phoneController.text;
        emailController.text = user.email ?? emailController.text;
        locationController.text = user.getCityName(true) ?? (user.getCityName(false) ?? locationController.text);
        if (!isClosed) {
          emit(state.copyWith(user: user));
        }
      },
    );
  }

  Future<void> updateLocation() async {
    emit(state.copyWith(status: EditProfileStatus.loading));
    final result = await _profileRepository.updateUserLocation();
    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            status: EditProfileStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (_) async {
        final profileRes = await _profileRepository.getUserProfile();
        profileRes.fold(
          (_) {
            if (!isClosed) {
              emit(state.copyWith(status: EditProfileStatus.locationUpdated));
            }
          },
          (user) {
            locationController.text = user.getCityName(true) ?? (user.getCityName(false) ?? locationController.text);
            if (!isClosed) {
              emit(state.copyWith(
                status: EditProfileStatus.locationUpdated,
                user: user,
              ));
            }
          },
        );
      },
    );
  }

  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && !isClosed) {
      emit(state.copyWith(
        avatarFile: File(pickedFile.path),
        status: EditProfileStatus.initial,
      ));
    }
  }

  Future<void> updateProfile() async {
    if (!(formKey.currentState?.validate() ?? true)) return;

    emit(state.copyWith(status: EditProfileStatus.loading));
    final result = await _profileRepository.updateProfile(
      UpdateProfileParams(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        avatarFile: state.avatarFile,
      ),
    );

    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            status: EditProfileStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (user) {
        if (!isClosed) {
          emit(state.copyWith(
            status: EditProfileStatus.success,
            user: user,
            clearAvatarFile: true,
          ));
        }
      },
    );
  }

  Future<void> deleteAccount() async {
    emit(state.copyWith(status: EditProfileStatus.loading));
    final result = await _authRepository.deleteAccount();

    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            status: EditProfileStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (_) {
        if (!isClosed) {
          emit(state.copyWith(status: EditProfileStatus.accountDeleted));
        }
      },
    );
  }

  @override
  Future<void> close() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    locationController.dispose();
    return super.close();
  }
}
