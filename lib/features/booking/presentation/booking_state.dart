import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum BookingStatus { initial, loading, success, error }
enum PlayMode { single, multi }

class BookingState extends Equatable {
  final BookingStatus status;
  final DateTime selectedDate;
  final TimeOfDay? startTime;
  final int durationHours;
  final List<TimeOfDay> bookedTimeSlots;
  final PlayMode playMode;
  final int extraControllersCount;

  const BookingState({
    this.status = BookingStatus.initial,
    required this.selectedDate,
    this.startTime,
    this.durationHours = 1,
    this.bookedTimeSlots = const [],
    this.playMode = PlayMode.single,
    this.extraControllersCount = 0,
  });

  BookingState copyWith({
    BookingStatus? status,
    DateTime? selectedDate,
    TimeOfDay? startTime,
    int? durationHours,
    List<TimeOfDay>? bookedTimeSlots,
    PlayMode? playMode,
    int? extraControllersCount,
  }) {
    return BookingState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      startTime: startTime ?? this.startTime,
      durationHours: durationHours ?? this.durationHours,
      bookedTimeSlots: bookedTimeSlots ?? this.bookedTimeSlots,
      playMode: playMode ?? this.playMode,
      extraControllersCount: extraControllersCount ?? this.extraControllersCount,
    );
  }

  @override
  List<Object?> get props => [status, selectedDate, startTime, durationHours, bookedTimeSlots, playMode, extraControllersCount];
}
