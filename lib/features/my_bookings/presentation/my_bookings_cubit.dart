import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/my_bookings_repo.dart';
import 'my_bookings_state.dart';

class MyBookingsCubit extends Cubit<MyBookingsState> {
  final MyBookingsRepository _repository;

  MyBookingsCubit(this._repository) : super(const MyBookingsState());

  Future<void> getMyBookings() async {
    emit(state.copyWith(status: MyBookingsStatus.loading));

    final result = await _repository.getMyBookings();

    result.fold(
      (failure) => emit(state.copyWith(status: MyBookingsStatus.failure, errorMessage: failure.message)),
      (bookings) {
        final upcoming = bookings.where((b) => b.status == 'upcoming').toList();
        final past = bookings.where((b) => b.status == 'completed').toList();
        final cancelled = bookings.where((b) => b.status == 'cancelled').toList();

        emit(state.copyWith(
          status: MyBookingsStatus.success,
          upcomingBookings: upcoming,
          pastBookings: past,
          cancelledBookings: cancelled,
        ));
      },
    );
  }

  Future<void> cancelBooking(String bookingId) async {
    emit(state.copyWith(status: MyBookingsStatus.loading));
    final result = await _repository.cancelBooking(bookingId);
    result.fold(
      (failure) => emit(state.copyWith(status: MyBookingsStatus.failure, errorMessage: failure.message)),
      (_) => getMyBookings(),
    );
  }
}
