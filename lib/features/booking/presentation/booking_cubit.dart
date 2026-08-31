import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/models/time_range.dart';
import '../data/models/booking_params.dart';
import '../domain/repositories/booking_repository.dart';
import 'booking_state.dart';

class BookingCubit extends Cubit<BookingState> {
  final BookingRepository _bookingRepository;
  final String roomId;
  final String loungeId;

  BookingCubit(
    this._bookingRepository,
    BookingDetailsParams params,
  )   : roomId = params.room.id,
        loungeId = params.lounge.id,
        super(BookingState(
          selectedDate: params.selectedDate,
          playMode: params.playMode == 'multi' ? PlayMode.multi : PlayMode.single,
          extraControllersCount: params.extraControllers,
        )) {
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
            .map((b) {
              final startAt = b['start_at'] ?? b['start_time'];
              final endAt = b['end_at'] ?? b['end_time'];
              final date = b['date'];

              if (startAt != null && endAt != null) {
                // If it's just time (HH:mm:ss), we need to prefix with date
                final startStr = startAt.toString().contains('-') ? startAt.toString() : "${date} $startAt";
                final endStr = endAt.toString().contains('-') ? endAt.toString() : "${date} $endAt";
                
                try {
                  final start = DateTime.parse(startStr.replaceFirst(' ', 'T'));
                  var end = DateTime.parse(endStr.replaceFirst(' ', 'T'));
                  
                  if (end.isBefore(start)) {
                    end = end.add(const Duration(days: 1));
                  }
                  
                  return TimeRange(start: start, end: end);
                } catch (e) {
                  return null;
                }
              }
              return null;
            })
            .whereType<TimeRange>()
            .toList();

        for (int h = 0; h < 24; h++) {
          // Check for :00 and :30 slots
          for (int m in [0, 30]) {
            final startCheck = h + (m / 60.0);
            final endCheck = startCheck + 0.5;
            final isOccupied = roomBookings.any((range) => range.overlaps(startCheck, endCheck));
            if (isOccupied) {
              bookedSlots.add(TimeOfDay(hour: h, minute: m));
            }
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

    final now = DateTime.now();
    final isToday = state.selectedDate.year == now.year &&
        state.selectedDate.month == now.month &&
        state.selectedDate.day == now.day;

    if (isToday) {
      // Create a DateTime for the slot to compare accurately
      var slotDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // If the slot is between 00:00 and 09:00, it's technically the next day's early morning
      // in our booking cycle (10:00 AM - 02:00 AM)
      if (time.hour < 10) {
        slotDateTime = slotDateTime.add(const Duration(days: 1));
      }

      // Buffer of 5 minutes to prevent booking something that is literally starting right now
      if (slotDateTime.isBefore(now.add(const Duration(minutes: 5)))) {
        return;
      }
    }

    emit(state.copyWith(startTime: time));
  }

  void setDurationMinutes(int minutes) {
    if (state.startTime != null && !isRangeAvailable(state.startTime!, minutes)) return;
    emit(state.copyWith(durationMinutes: minutes));
  }

  void updateDuration(int deltaMinutes) {
    final newDuration = (state.durationMinutes + deltaMinutes).clamp(30, 720); // 30 min to 12 hours
    if (state.startTime != null && !isRangeAvailable(state.startTime!, newDuration)) return;
    emit(state.copyWith(durationMinutes: newDuration));
  }

  bool isSlotBooked(TimeOfDay time) {
    // Basic implementation: check if the hour is fully or partially booked
    // For 30 min granularity, we might need more complex logic, 
    // but we'll stick to checking if any booking overlaps this slot.
    return state.bookedTimeSlots.any((slot) => slot.hour == time.hour && slot.minute == time.minute);
  }

  bool isRangeAvailable(TimeOfDay start, int durationMinutes) {
    final startDateTime = DateTime(2000, 1, 1, start.hour, start.minute);
    final endDateTime = startDateTime.add(Duration(minutes: durationMinutes));
    
    // We'd need to re-fetch roomBookings or store them in state to check properly.
    // For now, let's assume if the 30-min block's start is in bookedTimeSlots, it's unavailable.
    // Ideally, bookedTimeSlots should contain every 30-min block that is occupied.
    
    for (int i = 0; i < durationMinutes; i += 30) {
      final checkTime = startDateTime.add(Duration(minutes: i));
      final tod = TimeOfDay(hour: checkTime.hour, minute: checkTime.minute);
      if (state.bookedTimeSlots.any((slot) => slot.hour == tod.hour && slot.minute == tod.minute)) {
        return false;
      }
    }
    return true;
  }
}
