import 'dart:io';

/// Parameters for updating user profile
class UpdateProfileParams {
  final String name;
  final String phone;
  final String? email;
  final File? avatarFile;

  UpdateProfileParams({
    required this.name,
    required this.phone,
    this.email,
    this.avatarFile,
  });
}
