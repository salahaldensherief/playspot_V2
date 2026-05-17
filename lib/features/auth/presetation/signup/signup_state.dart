
import 'package:playspot/features/auth/data/models/user_model.dart';

enum SignupStatus {
  initial,
  loading,
  success,
  successSocial, // بعد Google/Facebook محتاج complete profile
  failure;

  bool get isInitial      => this == SignupStatus.initial;
  bool get isLoading      => this == SignupStatus.loading;
  bool get isSuccess      => this == SignupStatus.success;
  bool get isSuccessSocial => this == SignupStatus.successSocial;
  bool get isFailure      => this == SignupStatus.failure;
}

class SignupState {
  final SignupStatus status;
  final UserModel params;
  final String? errorMessage;

  SignupState({
    this.status = SignupStatus.initial,
    required this.params,
    this.errorMessage,
  });

  factory SignupState.init() {
    return SignupState(
      params: UserModel(
        id: '',
        email: '',
        phone: '',
        avatarUrl: '',
      ),
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
}