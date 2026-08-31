
import 'package:equatable/equatable.dart';
import 'package:playspot/features/auth/data/models/user_model.dart';

enum LoginStatus {
  initial,
  loading,
  success,
  successSocial,
  failure;

  bool get isInitial       => this == LoginStatus.initial;
  bool get isLoading       => this == LoginStatus.loading;
  bool get isSuccess       => this == LoginStatus.success;
  bool get isSuccessSocial => this == LoginStatus.successSocial;
  bool get isFailure       => this == LoginStatus.failure;
}

class LoginState extends Equatable {
  final LoginStatus status;
  final UserModel params;
  final String? errorMessage;

  const LoginState({
    this.status = LoginStatus.initial,
    required this.params,
    this.errorMessage,
  });

  factory LoginState.init() {
    return LoginState(
      params: const UserModel(id: '', email: ''),
      status: LoginStatus.initial,
    );
  }

  LoginState copyWith({
    LoginStatus? status,
    UserModel? params,
    String? errorMessage,
  }) {
    return LoginState(
      status: status ?? this.status,
      params: params ?? this.params,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, params, errorMessage];
}