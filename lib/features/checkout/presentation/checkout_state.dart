import 'package:equatable/equatable.dart';

enum PaymentMethod { vodafoneCash, instaPay, cash }
enum CheckoutStatus { initial, loading, success, failure }

class CheckoutState extends Equatable {
  final CheckoutStatus status;
  final PaymentMethod selectedMethod;
  final String? errorMessage;
  final Map<String, dynamic>? selectedVoucher;
  final double discountAmount;
  final bool allowCashPayment;
  final bool isCashEnabled;
  final int completedBookingsCount;
  final String? cashDisabledReason;
  final String? senderWalletNumber;

  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.selectedMethod = PaymentMethod.vodafoneCash,
    this.errorMessage,
    this.selectedVoucher,
    this.discountAmount = 0,
    this.allowCashPayment = true,
    this.isCashEnabled = true,
    this.completedBookingsCount = 0,
    this.cashDisabledReason,
    this.senderWalletNumber,
  });

  CheckoutState copyWith({
    CheckoutStatus? status,
    PaymentMethod? selectedMethod,
    String? errorMessage,
    Map<String, dynamic>? selectedVoucher,
    double? discountAmount,
    bool? allowCashPayment,
    bool? isCashEnabled,
    int? completedBookingsCount,
    String? cashDisabledReason,
    String? senderWalletNumber,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      errorMessage: errorMessage,
      selectedVoucher: selectedVoucher ?? this.selectedVoucher,
      discountAmount: discountAmount ?? this.discountAmount,
      allowCashPayment: allowCashPayment ?? this.allowCashPayment,
      isCashEnabled: isCashEnabled ?? this.isCashEnabled,
      completedBookingsCount: completedBookingsCount ?? this.completedBookingsCount,
      cashDisabledReason: cashDisabledReason ?? this.cashDisabledReason,
      senderWalletNumber: senderWalletNumber ?? this.senderWalletNumber,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedMethod,
        errorMessage,
        selectedVoucher,
        discountAmount,
        allowCashPayment,
        isCashEnabled,
        completedBookingsCount,
        cashDisabledReason,
        senderWalletNumber,
      ];
}
