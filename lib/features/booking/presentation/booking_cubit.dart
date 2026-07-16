import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/models/time_range.dart';
import '../data/repos/booking_repo.dart';
import 'booking_state.dart';

class BookingCubit extends Cubit<BookingState> {
  final BookingRepository _bookingRepository;
  final String roomId;
  final String loungeId;

  BookingCubit(this._bookingRepository, this.roomId, this.loungeId, DateTime? initialDate)
      : super(BookingState(selectedDate: initialDate ?? DateTime.now())) {
    fetchBookedSlots(state.selectedDate);
  }

  Future<void> fetchBookedSlots(DateTime date) async {
    emit(state.copyWith(status: BookingStatus.loading, selectedDate: date));
    
    final result = await _bookingRepository.getRoomBookingsForDate(loungeId, date);
    
    result.fold(
      (failure) => emit(state.copyWith(status: BookingStatus.error)),
      (rawBookings) {
        List<TimeOfDay> bookedSlots = [];
        
        final roomBookings = rawBookings
            .where((b) => b['room_id'].toString() == roomId)
            .map((b) => TimeRange(
                  start: DateTime.parse(b['start_at']),
                  end: DateTime.parse(b['end_at']),
                ))
            .toList();

        for (int h = 0; h < 24; h++) {
          final isOccupied = roomBookings.any((range) => range.overlaps(h, h + 1));
          if (isOccupied) {
            bookedSlots.add(TimeOfDay(hour: h, minute: 0));
          }
        }

        emit(state.copyWith(status: BookingStatus.success, bookedTimeSlots: bookedSlots));
      },
    );
  }

  void selectDate(DateTime date) {
    if (date.year == state.selectedDate.year &&
        date.month == state.selectedDate.month &&
        date.day == state.selectedDate.day) return;
    
    fetchBookedSlots(date);
  }

  void selectStartTime(TimeOfDay time) {
    if (isSlotBooked(time)) return;
    emit(state.copyWith(startTime: time));
  }

  void updateDuration(int delta) {
    final newDuration = (state.durationHours + delta).clamp(1, 12);
    if (state.startTime != null && !isRangeAvailable(state.startTime!, newDuration)) return;
    emit(state.copyWith(durationHours: newDuration));
  }

  bool isSlotBooked(TimeOfDay time) {
    return state.bookedTimeSlots.any((slot) => slot.hour == time.hour);
  }

  bool isRangeAvailable(TimeOfDay start, int duration) {
    for (int i = 0; i < duration; i++) {
      final hourToCheck = (start.hour + i) % 24;
      if (state.bookedTimeSlots.any((slot) => slot.hour == hourToCheck)) return false;
    }
    return true;
  }
}
