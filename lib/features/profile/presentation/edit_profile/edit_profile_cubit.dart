import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/repos/profile_repo.dart';
import '../../../../core/di/modules/auth_module.dart';
import '../../../auth/data/repos/auth_repos.dart';
import 'edit_profile_state.dart';

class EditProfileCubit extends Cubit<EditProfileState> {
  final ProfileRepository _profileRepository;
  final AuthRepository _authRepository;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  File? avatarFile;

  EditProfileCubit(this._profileRepository, this._authRepository) : super(EditProfileState());

  void init() {
    final user = _profileRepository.getCurrentUser();
    nameController.text = user?.name ?? '';
    phoneController.text = user?.phone ?? '';
    emailController.text = user?.email ?? '';
    emit(state.copyWith(user: user));
  }

  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      avatarFile = File(pickedFile.path);
      emit(state.copyWith(status: EditProfileStatus.initial)); // Force rebuild for image
    }
  }

  Future<void> updateProfile() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    emit(state.copyWith(status: EditProfileStatus.loading));
    final result = await _profileRepository.updateProfile(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      email: emailController.text.trim(),
      avatarFile: avatarFile,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: EditProfileStatus.error,
        errorMessage: failure.message,
      )),
      (user) => emit(state.copyWith(
        status: EditProfileStatus.success,
        user: user,
      )),
    );
  }

  Future<void> deleteAccount() async {
    emit(state.copyWith(status: EditProfileStatus.loading));
    final result = await _authRepository.deleteAccount();

    result.fold(
      (failure) => emit(state.copyWith(
        status: EditProfileStatus.error,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(status: EditProfileStatus.accountDeleted)),
    );
  }

  @override
  Future<void> close() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    return super.close();
  }
}
