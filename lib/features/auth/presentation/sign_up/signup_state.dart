

import 'package:equatable/equatable.dart';
import '../../data/models/user_model.dart';

enum SignupStatus {
  initial,
  loading,
  success,         // روح Home
  successSocial,   // روح Complete Profile (يوزر جديد)
  failure;

  bool get isInitial       => this == SignupStatus.initial;
  bool get isLoading       => this == SignupStatus.loading;
  bool get isSuccess       => this == SignupStatus.success;
  bool get isSuccessSocial => this == SignupStatus.successSocial;
  bool get isFailure       => this == SignupStatus.failure;
}

class SignupState extends Equatable {
  final SignupStatus status;
  final UserModel params;
  final String? errorMessage;

  const SignupState({
    this.status = SignupStatus.initial,
    required this.params,
    this.errorMessage,
  });

  factory SignupState.init() {
    return SignupState(
      params: const UserModel(id: '', email: '', phone: '', avatarUrl: ''),
      status: SignupStatus.initial,
    );
  }

  SignupState copyWith({
    SignupStatus? status,
    UserModel? params,
    String? errorMessage,
  }) {
    return SignupState(
      status: status ?? this.status,
      params: params ?? this.params,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, params, errorMessage];
}