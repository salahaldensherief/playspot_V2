import 'package:equatable/equatable.dart';
import '../domain/entities/booking_timeline_item.dart';

enum RequestStatus { initial, loading, success, failure }

class BookingTimelineState extends Equatable {
  final RequestStatus status;
  final List<BookingTimelineItem> items;
  final String? errorMessage;

  const BookingTimelineState({
    this.status = RequestStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  BookingTimelineState copyWith({
    RequestStatus? status,
    List<BookingTimelineItem>? items,
    String? errorMessage,
  }) {
    return BookingTimelineState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
