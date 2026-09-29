import 'package:equatable/equatable.dart';
import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';

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
  final Map<String, dynamic>? serverQuote;
  final bool paymentProofUploadFailed;

  double? get serverFinalTotal =>
      (serverQuote?['final_total'] as num?)?.toDouble();

  double? get serverOriginalTotal =>
      (serverQuote?['original_total'] as num?)?.toDouble();

  double? get serverPromoDiscount =>
      (serverQuote?['promo_discount_total'] as num?)?.toDouble();

  // Hold Timer fields
  final int remainingSeconds;
  final bool isHoldExpired;
  final DateTime? holdExpiresAt;
  final String? holdToken;

  // Realtime Booking Listener fields
  final String? createdBookingId;
  final BookingStatus? liveBookingStatus;
  final String? rejectionReason;
  final BookingModel? confirmedBooking;

  final PriceChangedFailure? priceChangedFailure;

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
    this.serverQuote,
    this.paymentProofUploadFailed = false,
    this.remainingSeconds = 600,
    this.isHoldExpired = false,
    this.holdExpiresAt,
    this.holdToken,
    this.createdBookingId,
    this.liveBookingStatus,
    this.rejectionReason,
    this.confirmedBooking,
    this.priceChangedFailure,
  });

  String get formattedRemainingTime {
    final minutes = (remainingSeconds / 60).floor();
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

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
    Map<String, dynamic>? serverQuote,
    bool? paymentProofUploadFailed,
    bool clearVoucher = false,
    int? remainingSeconds,
    bool? isHoldExpired,
    DateTime? holdExpiresAt,
    String? holdToken,
    bool clearHold = false,
    String? createdBookingId,
    BookingStatus? liveBookingStatus,
    String? rejectionReason,
    BookingModel? confirmedBooking,
    PriceChangedFailure? priceChangedFailure,
    bool clearPriceChangedFailure = false,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      errorMessage: errorMessage,
      selectedVoucher: clearVoucher
          ? null
          : (selectedVoucher ?? this.selectedVoucher),
      discountAmount: clearVoucher
          ? 0
          : (discountAmount ?? this.discountAmount),
      allowCashPayment: allowCashPayment ?? this.allowCashPayment,
      isCashEnabled: isCashEnabled ?? this.isCashEnabled,
      completedBookingsCount:
          completedBookingsCount ?? this.completedBookingsCount,
      cashDisabledReason: cashDisabledReason ?? this.cashDisabledReason,
      senderWalletNumber: senderWalletNumber ?? this.senderWalletNumber,
      serverQuote: serverQuote ?? this.serverQuote,
      paymentProofUploadFailed:
          paymentProofUploadFailed ?? this.paymentProofUploadFailed,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isHoldExpired: isHoldExpired ?? this.isHoldExpired,
      holdExpiresAt: clearHold ? null : (holdExpiresAt ?? this.holdExpiresAt),
      holdToken: clearHold ? null : (holdToken ?? this.holdToken),
      createdBookingId: createdBookingId ?? this.createdBookingId,
      liveBookingStatus: liveBookingStatus ?? this.liveBookingStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      confirmedBooking: confirmedBooking ?? this.confirmedBooking,
      priceChangedFailure: clearPriceChangedFailure
          ? null
          : (priceChangedFailure ?? this.priceChangedFailure),
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
    serverQuote,
    paymentProofUploadFailed,
    remainingSeconds,
    isHoldExpired,
    holdExpiresAt,
    holdToken,
    createdBookingId,
    liveBookingStatus,
    rejectionReason,
    confirmedBooking,
    priceChangedFailure,
  ];
}
