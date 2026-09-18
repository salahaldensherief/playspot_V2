import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
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
  double calculateExtrasPrice(BookingDetailsParams params) {
    return params.extras.fold<double>(
      0,
      (sum, item) =>
          sum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toDouble()),
    );
  }

  double calculateAppliedRate(BookingDetailsParams params) {
    return playMode == PlayMode.single
        ? params.room.effectivePriceSingle
        : params.room.effectivePriceMulti;
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
    final extras = calculateExtrasPrice(params);
    final appliedRate = calculateAppliedRate(params);
    final controllers = calculateExtraControllersCharge(params);
    final durationHours = durationMinutes / 60.0;
    return ((appliedRate + controllers) * durationHours) + extras;
  }

  double calculateOriginalTotalPrice(BookingDetailsParams params) {
    final extras = calculateExtrasPrice(params);
    final originalRate = calculateOriginalRate(params);
    final controllers = calculateExtraControllersCharge(params);
    final durationHours = durationMinutes / 60.0;
    return ((originalRate + controllers) * durationHours) + extras;
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
