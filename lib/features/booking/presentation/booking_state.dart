import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../data/models/booking_offer_info.dart';
import '../data/models/booking_params.dart';

enum BookingStatus { initial, loading, success, error }
enum PlayMode { single, multi }

class BookingState extends Equatable {
  final BookingStatus status;
  final DateTime selectedDate;
  final TimeOfDay? startTime;
  final int durationMinutes;
  final List<TimeOfDay> bookedTimeSlots;
  final PlayMode playMode;
  final int extraControllersCount;
  final String? errorMessage;

  const BookingState({
    this.status = BookingStatus.initial,
    required this.selectedDate,
    this.startTime,
    this.durationMinutes = 60,
    this.bookedTimeSlots = const [],
    this.playMode = PlayMode.single,
    this.extraControllersCount = 0,
    this.errorMessage,
  });

  BookingState copyWith({
    BookingStatus? status,
    DateTime? selectedDate,
    TimeOfDay? startTime,
    bool clearStartTime = false,
    int? durationMinutes,
    List<TimeOfDay>? bookedTimeSlots,
    PlayMode? playMode,
    int? extraControllersCount,
    String? errorMessage,
  }) {
    return BookingState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      durationMinutes: durationMinutes ?? this.durationMinutes,
      bookedTimeSlots: bookedTimeSlots ?? this.bookedTimeSlots,
      playMode: playMode ?? this.playMode,
      extraControllersCount: extraControllersCount ?? this.extraControllersCount,
      errorMessage: errorMessage,
    );
  }

  // ─── Price & Logic Calculations ──────────────────────────────
  BookingOfferInfo getOfferInfo(BookingDetailsParams params, bool isArabic) {
    return BookingOfferInfo.resolve(
      room: params.room,
      lounge: params.lounge,
      isSinglePlay: playMode == PlayMode.single,
      isArabic: isArabic,
    );
  }

  Map<String, double> getCalculatedSubtotals(BookingDetailsParams params, bool isArabic) {
    final offerInfo = getOfferInfo(params, isArabic);
    return offerInfo.calculateSubtotals(
      durationMinutes: durationMinutes,
      extraControllersCount: extraControllersCount,
      extraControllerPrice: params.room.extraControllerPrice,
      extras: params.extras,
    );
  }

  double calculateExtrasPrice(BookingDetailsParams params) {
    return params.extras.fold<double>(
      0,
      (sum, item) =>
          sum + (((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toDouble() ?? 1.0)),
    );
  }

  double calculateAppliedRate(BookingDetailsParams params) {
    final offerInfo = BookingOfferInfo.resolve(
      room: params.room,
      lounge: params.lounge,
      isSinglePlay: playMode == PlayMode.single,
      isArabic: true,
    );
    return offerInfo.discountedHourlyRate;
  }

  double calculateOriginalRate(BookingDetailsParams params) {
    return playMode == PlayMode.single
        ? params.room.hourlyRateSingle
        : params.room.hourlyRateMulti;
  }

  double calculateExtraControllersCharge(BookingDetailsParams params) {
    return extraControllersCount * params.room.extraControllerPrice;
  }

  double calculateTotalPrice(BookingDetailsParams params) {
    final subtotals = getCalculatedSubtotals(params, true);
    return subtotals['totalPrice'] ?? 0.0;
  }

  double calculateOriginalTotalPrice(BookingDetailsParams params) {
    final subtotals = getCalculatedSubtotals(params, true);
    return subtotals['originalTotalPrice'] ?? 0.0;
  }

  // ─── Smart Localized Duration Formatting ──────────────────────
  String getFormattedDuration(bool isArabic) {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;

    if (isArabic) {
      if (hours > 0 && mins > 0) {
        return '$hours س و $mins د';
      } else if (hours > 0) {
        if (hours == 1) return 'ساعة واحدة';
        if (hours == 2) return 'ساعتان';
        if (hours >= 3 && hours <= 10) return '$hours ساعات';
        return '$hours ساعة';
      } else {
        return '$mins دقيقة';
      }
    } else {
      if (hours > 0 && mins > 0) {
        return '$hours hr $mins min';
      } else if (hours > 0) {
        return hours == 1 ? '1 hour' : '$hours hours';
      } else {
        return '$mins mins';
      }
    }
  }

  @override
  List<Object?> get props => [
        status,
        selectedDate,
        startTime,
        durationMinutes,
        bookedTimeSlots,
        playMode,
        extraControllersCount,
        errorMessage,
      ];
}
