import 'dart:io';

/// Parameters for creating a new user account
class SignUpParams {
  final String email;
  final String password;
  final String name;
  final String phone;
  final File? avatarFile;
  final String? referralCode;

  SignUpParams({
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    this.avatarFile,
    this.referralCode,
  });
}

/// Parameters for completing user profile
class CompleteProfileParams {
  final String userId;
  final String phone;
  final File? avatarFile;

  CompleteProfileParams({
    required this.userId,
    required this.phone,
    this.avatarFile,
  });
}
