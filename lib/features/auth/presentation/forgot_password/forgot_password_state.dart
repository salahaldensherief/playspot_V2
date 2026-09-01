import 'package:equatable/equatable.dart';

enum ForgotPasswordStatus {
  initial,
  loading,
  emailSent,
  otpVerified,
  success,
  failure,
}

extension ForgotPasswordStatusX on ForgotPasswordStatus {
  bool get isInitial => this == ForgotPasswordStatus.initial;
  bool get isLoading => this == ForgotPasswordStatus.loading;
  bool get isEmailSent => this == ForgotPasswordStatus.emailSent;
  bool get isOtpVerified => this == ForgotPasswordStatus.otpVerified;
  bool get isSuccess => this == ForgotPasswordStatus.success;
  bool get isFailure => this == ForgotPasswordStatus.failure;
}

class ForgotPasswordState extends Equatable {
  final ForgotPasswordStatus status;
  final String? errorMessage;
  final String? email;

  const ForgotPasswordState({
    required this.status,
    this.errorMessage,
    this.email,
  });

  factory ForgotPasswordState.initial() => const ForgotPasswordState(
        status: ForgotPasswordStatus.initial,
      );

  ForgotPasswordState copyWith({
    ForgotPasswordStatus? status,
    String? errorMessage,
    String? email,
  }) {
    return ForgotPasswordState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      email: email ?? this.email,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, email];
}
