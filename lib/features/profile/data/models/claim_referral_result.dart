import 'package:equatable/equatable.dart';

enum ClaimReferralStatus {
  success,
  alreadyClaimed,
  emailUnconfirmed,
  invalidCode,
  error,
}

class ClaimReferralResult extends Equatable {
  final ClaimReferralStatus status;
  final String messageKey;

  const ClaimReferralResult({
    required this.status,
    required this.messageKey,
  });

  @override
  List<Object?> get props => [status, messageKey];
}
