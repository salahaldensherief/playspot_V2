import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/booking_error_formatter.dart';
import '../domain/entities/booking_timeline_item.dart';
import '../domain/usecases/get_booking_timeline_usecase.dart';
import 'booking_timeline_state.dart';

class BookingTimelineCubit extends Cubit<BookingTimelineState> {
  final GetBookingTimelineUseCase _getBookingTimelineUseCase;

  BookingTimelineCubit(this._getBookingTimelineUseCase) : super(const BookingTimelineState());

  Future<void> fetchTimeline(String bookingId, {bool isArabic = true}) async {
    emit(state.copyWith(status: RequestStatus.loading, errorMessage: null));

    final result = await _getBookingTimelineUseCase(bookingId);

    result.fold(
      (failure) {
        final localizedMsg = getBookingErrorMessage(failure.message, !isArabic);
        emit(state.copyWith(
          status: RequestStatus.failure,
          errorMessage: localizedMsg,
        ));
      },
      (fetchedItems) {
        final deduplicated = <BookingTimelineItem>[];
        final seenIds = <String>{};

        for (final item in fetchedItems) {
          if (seenIds.add(item.id)) {
            deduplicated.add(item);
          }
        }

        emit(state.copyWith(
          status: RequestStatus.success,
          items: deduplicated,
          errorMessage: null,
        ));
      },
    );
  }
}
