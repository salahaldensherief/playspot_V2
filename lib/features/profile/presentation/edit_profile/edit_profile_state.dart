import '../../../auth/data/models/user_model.dart';

enum EditProfileStatus { initial, loading, success, error }

class EditProfileState {
  final EditProfileStatus status;
  final UserModel? user;
  final String? errorMessage;

  EditProfileState({
    this.status = EditProfileStatus.initial,
    this.user,
    this.errorMessage,
  });

  EditProfileState copyWith({
    EditProfileStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return EditProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
