import 'package:equatable/equatable.dart';
import '../data/models/booking_model.dart';

enum MyBookingsStatus { initial, loading, success, failure }

class MyBookingsState extends Equatable {
  final MyBookingsStatus status;
  final List<BookingModel> upcomingBookings;
  final List<BookingModel> pastBookings;
  final List<BookingModel> cancelledBookings;
  final String? errorMessage;

  const MyBookingsState({
    this.status = MyBookingsStatus.initial,
    this.upcomingBookings = const [],
    this.pastBookings = const [],
    this.cancelledBookings = const [],
    this.errorMessage,
  });

  MyBookingsState copyWith({
    MyBookingsStatus? status,
    List<BookingModel>? upcomingBookings,
    List<BookingModel>? pastBookings,
    List<BookingModel>? cancelledBookings,
    String? errorMessage,
  }) {
    return MyBookingsState(
      status: status ?? this.status,
      upcomingBookings: upcomingBookings ?? this.upcomingBookings,
      pastBookings: pastBookings ?? this.pastBookings,
      cancelledBookings: cancelledBookings ?? this.cancelledBookings,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, upcomingBookings, pastBookings, cancelledBookings, errorMessage];
}
