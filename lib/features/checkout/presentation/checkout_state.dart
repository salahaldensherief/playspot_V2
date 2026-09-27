import 'package:equatable/equatable.dart';
import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';

enum PaymentMethod { vodafoneCash, instaPay, cash }
enum CheckoutStatus { initial, loading, success, failure }

class CheckoutState extends Equatable {
  final CheckoutStatus status;
  final PaymentMethod selectedMethod;
  final String? errorMessage;
  final Map<String, dynamic>? selectedVoucher;
  final double discountAmount;
  final Map<String, dynamic>? bookingQuote;
  final bool allowCashPayment;
  final bool isCashEnabled;
  final int completedBookingsCount;
  final String? cashDisabledReason;
  final String? senderWalletNumber;

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

  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.selectedMethod = PaymentMethod.vodafoneCash,
    this.errorMessage,
    this.selectedVoucher,
    this.discountAmount = 0,
    this.bookingQuote,
    this.allowCashPayment = true,
    this.isCashEnabled = true,
    this.completedBookingsCount = 0,
    this.cashDisabledReason,
    this.senderWalletNumber,
    this.remainingSeconds = 600,
    this.isHoldExpired = false,
    this.holdExpiresAt,
    this.holdToken,
    this.createdBookingId,
    this.liveBookingStatus,
    this.rejectionReason,
    this.confirmedBooking,
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
    bool clearSelectedVoucher = false,
    double? discountAmount,
    Map<String, dynamic>? bookingQuote,
    bool clearBookingQuote = false,
    bool? allowCashPayment,
    bool? isCashEnabled,
    int? completedBookingsCount,
    String? cashDisabledReason,
    String? senderWalletNumber,
    int? remainingSeconds,
    bool? isHoldExpired,
    DateTime? holdExpiresAt,
    String? holdToken,
    bool clearHold = false,
    String? createdBookingId,
    BookingStatus? liveBookingStatus,
    String? rejectionReason,
    BookingModel? confirmedBooking,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      errorMessage: errorMessage,
      selectedVoucher: clearSelectedVoucher
          ? null
          : (selectedVoucher ?? this.selectedVoucher),
      discountAmount: discountAmount ?? this.discountAmount,
      bookingQuote: clearBookingQuote
          ? null
          : (bookingQuote ?? this.bookingQuote),
      allowCashPayment: allowCashPayment ?? this.allowCashPayment,
      isCashEnabled: isCashEnabled ?? this.isCashEnabled,
      completedBookingsCount: completedBookingsCount ?? this.completedBookingsCount,
      cashDisabledReason: cashDisabledReason ?? this.cashDisabledReason,
      senderWalletNumber: senderWalletNumber ?? this.senderWalletNumber,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isHoldExpired: isHoldExpired ?? this.isHoldExpired,
      holdExpiresAt: clearHold ? null : (holdExpiresAt ?? this.holdExpiresAt),
      holdToken: clearHold ? null : (holdToken ?? this.holdToken),
      createdBookingId: createdBookingId ?? this.createdBookingId,
      liveBookingStatus: liveBookingStatus ?? this.liveBookingStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      confirmedBooking: confirmedBooking ?? this.confirmedBooking,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedMethod,
        errorMessage,
        selectedVoucher,
        discountAmount,
        bookingQuote,
        allowCashPayment,
        isCashEnabled,
        completedBookingsCount,
        cashDisabledReason,
        senderWalletNumber,
        remainingSeconds,
        isHoldExpired,
        holdExpiresAt,
        holdToken,
        createdBookingId,
        liveBookingStatus,
        rejectionReason,
        confirmedBooking,
      ];
}
