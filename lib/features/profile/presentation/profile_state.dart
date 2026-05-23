import '../../auth/data/models/user_model.dart';

enum ProfileStatus { initial, loading, success, error, logoutSuccess }

class ProfileState {
  final ProfileStatus status;
  final UserModel? user;
  final String? errorMessage;

  ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.errorMessage,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
