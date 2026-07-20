import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/data/repos/auth_repos.dart';
import '../data/repos/profile_repo.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  ProfileCubit(this._authRepository, this._profileRepository) : super(ProfileState());

  void getUserData() {
    emit(state.copyWith(status: ProfileStatus.loading));
    final user = _profileRepository.getCurrentUser();
    if (user != null) {
      emit(state.copyWith(status: ProfileStatus.success, user: user));
    } else {
      emit(state.copyWith(status: ProfileStatus.error, errorMessage: "User not found"));
    }
  }

  Future<void> logout() async {
    emit(state.copyWith(status: ProfileStatus.loading));
    final result = await _authRepository.signOut();
    
    result.fold(
      (failure) => emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(status: ProfileStatus.logoutSuccess)),
    );
  }
}
