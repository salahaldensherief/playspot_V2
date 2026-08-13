import 'package:equatable/equatable.dart';

enum PaymentMethod { creditCard, vodafoneCash, fawry, cash }
enum CheckoutStatus { initial, loading, success, failure }

class CheckoutState extends Equatable {
  final CheckoutStatus status;
  final PaymentMethod selectedMethod;
  final String? errorMessage;
  final Map<String, dynamic>? selectedVoucher;
  final double discountAmount;

  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.selectedMethod = PaymentMethod.creditCard,
    this.errorMessage,
    this.selectedVoucher,
    this.discountAmount = 0,
  });

  CheckoutState copyWith({
    CheckoutStatus? status,
    PaymentMethod? selectedMethod,
    String? errorMessage,
    Map<String, dynamic>? selectedVoucher,
    double? discountAmount,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      errorMessage: errorMessage,
      selectedVoucher: selectedVoucher ?? this.selectedVoucher,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }

  @override
  List<Object?> get props => [status, selectedMethod, errorMessage, selectedVoucher, discountAmount];
}
