import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';

abstract class BookingRepository {
  Future<Either<Failure, List<Map<String, dynamic>>>> getRoomBookingsForDate(String loungeId, DateTime date, {String? roomId});
  Future<Either<Failure, bool>> checkRoomAvailability({required String roomId, required DateTime startTime, required DateTime endTime});
  Future<Either<Failure, Map<String, dynamic>>> acquireBookingHold({required List<String> roomIds, required DateTime startTime, required DateTime endTime, int holdMinutes = 10});
  Future<Either<Failure, void>> releaseBookingHold(String holdToken);
  Future<Either<Failure, Map<String, dynamic>>> quoteBookingCheckout({
    required String holdToken,
    required List<Map<String, dynamic>> roomRequests,
    required List<Map<String, dynamic>> extraItems,
    String? voucherCode,
  });
  Future<Either<Failure, Map<String, dynamic>>> createBookingCheckout({
    required String holdToken,
    required List<Map<String, dynamic>> roomRequests,
    required List<Map<String, dynamic>> extraItems,
    String? voucherCode,
    required String paymentMethod,
    String? senderWalletPhone,
    String? receiptUrl,
  });
  Future<Either<Failure, Map<String, dynamic>>> createBooking(CreateBookingParams params);
  Stream<BookingModel> watchBookingStatus(String bookingId);
  Future<Either<Failure, void>> extendSession({
    required String bookingId,
    required int additionalMinutes,
    required double additionalCost,
  });
  Future<Either<Failure, void>> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  });
  Future<Either<Failure, void>> callStaff({
    required String loungeId,
    required String bookingId,
    required String reason,
    required String note,
  });
  Future<Either<Failure, void>> placeCanteenOrder({
    required String bookingId,
    required String loungeId,
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String note,
  });
}
