import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum BookingStatus { initial, loading, success, error }

class BookingState extends Equatable {
  final BookingStatus status;
  final DateTime selectedDate;
  final TimeOfDay? startTime;
  final int durationHours;
  final List<TimeOfDay> bookedTimeSlots;

  const BookingState({
    this.status = BookingStatus.initial,
    required this.selectedDate,
    this.startTime,
    this.durationHours = 1,
    this.bookedTimeSlots = const [],
  });

  BookingState copyWith({
    BookingStatus? status,
    DateTime? selectedDate,
    TimeOfDay? startTime,
    int? durationHours,
    List<TimeOfDay>? bookedTimeSlots,
  }) {
    return BookingState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      startTime: startTime ?? this.startTime,
      durationHours: durationHours ?? this.durationHours,
      bookedTimeSlots: bookedTimeSlots ?? this.bookedTimeSlots,
    );
  }

  @override
  List<Object?> get props => [status, selectedDate, startTime, durationHours, bookedTimeSlots];
}
