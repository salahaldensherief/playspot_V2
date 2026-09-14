import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/features/auth/domain/repositories/auth_repository.dart';
import 'package:playspot/features/profile/data/models/profile_params.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'edit_profile_state.dart';

class EditProfileCubit extends Cubit<EditProfileState> {
  final ProfileRepository _profileRepository;
  final AuthRepository _authRepository;
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  File? avatarFile;

  EditProfileCubit(this._profileRepository, this._authRepository) : super(const EditProfileState());

  Future<void> init() async {
    final currentUser = _profileRepository.getCurrentUser();
    nameController.text = currentUser?.name ?? '';
    phoneController.text = currentUser?.phone ?? '';
    emailController.text = currentUser?.email ?? '';

    emit(state.copyWith(user: currentUser, selectedCityId: currentUser?.cityId));

    // Fetch full profile to get city_id if not loaded
    final profileRes = await _profileRepository.getUserProfile();
    profileRes.fold(
      (_) {},
      (user) {
        nameController.text = user.name ?? nameController.text;
        phoneController.text = user.phone ?? phoneController.text;
        emailController.text = user.email ?? emailController.text;
        if (!isClosed) {
          emit(state.copyWith(
            user: user,
            selectedCityId: user.cityId ?? state.selectedCityId,
          ));
        }
      },
    );

    // Fetch cities list
    try {
      final citiesRes = await _supabase.from('cities').select();
      final citiesList = List<Map<String, dynamic>>.from(citiesRes as List);
      if (!isClosed) {
        emit(state.copyWith(cities: citiesList));
      }
    } catch (_) {
      try {
        final citiesRes = await _supabase.rpc('get_available_cities');
        final citiesList = List<Map<String, dynamic>>.from(citiesRes as List);
        if (!isClosed) {
          emit(state.copyWith(cities: citiesList));
        }
      } catch (_) {}
    }
  }

  void selectCity(String? cityId) {
    emit(state.copyWith(selectedCityId: cityId));
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
      UpdateProfileParams(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        cityId: state.selectedCityId,
        avatarFile: avatarFile,
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
    return super.close();
  }
}
