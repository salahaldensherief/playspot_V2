import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

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

