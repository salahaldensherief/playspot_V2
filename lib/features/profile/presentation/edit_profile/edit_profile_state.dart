import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:playspot/features/auth/data/models/user_model.dart';

enum EditProfileStatus { initial, loading, success, locationUpdated, error, accountDeleted }

class EditProfileState extends Equatable {
  final EditProfileStatus status;
  final UserModel? user;
  final File? avatarFile;
  final String? errorMessage;

  const EditProfileState({
    this.status = EditProfileStatus.initial,
    this.user,
    this.avatarFile,
    this.errorMessage,
  });

  EditProfileState copyWith({
    EditProfileStatus? status,
    UserModel? user,
    File? avatarFile,
    bool clearAvatarFile = false,
    String? errorMessage,
  }) {
    return EditProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      avatarFile: clearAvatarFile ? null : (avatarFile ?? this.avatarFile),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, avatarFile, errorMessage];
}
