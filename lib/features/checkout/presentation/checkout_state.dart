import 'package:equatable/equatable.dart';

enum PaymentMethod { creditCard, vodafoneCash, fawry, cash }
enum CheckoutStatus { initial, loading, success, failure }

class CheckoutState extends Equatable {
  final CheckoutStatus status;
  final PaymentMethod selectedMethod;
  final String? errorMessage;

  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.selectedMethod = PaymentMethod.creditCard,
    this.errorMessage,
  });

  CheckoutState copyWith({
    CheckoutStatus? status,
    PaymentMethod? selectedMethod,
    String? errorMessage,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, selectedMethod, errorMessage];
}
