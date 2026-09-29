import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/utils/repository_helper.dart';
import 'package:playspot/features/booking/data/models/booking_price_quote_model.dart';
import 'package:playspot/features/booking/data/models/lounge_price_range_model.dart';
import 'package:playspot/features/booking/data/models/room_slot_price_model.dart';
import 'package:playspot/features/booking/domain/entities/booking_price_quote.dart';
import 'package:playspot/features/booking/domain/entities/lounge_price_range.dart';
import 'package:playspot/features/booking/domain/entities/room_slot_price.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/booking/data/datasources/remote/booking_remote_data_source.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';

class BookingRepositoryImpl with RepositoryHelper implements BookingRepository {
  final BookingRemoteDataSource _remoteDataSource;

  BookingRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRoomBookingsForDate(
    String loungeId,
    DateTime date, {
    String? roomId,
  }) async {
    return await callRepository(
      () => _remoteDataSource.getRoomBookingsForDate(
        loungeId,
        date,
        roomId: roomId,
      ),
    );
  }

  @override
  Future<Either<Failure, bool>> checkRoomAvailability({
    required String roomId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    return await callRepository(
      () => _remoteDataSource.checkRoomAvailability(
        roomId: roomId,
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> acquireBookingHold({
    required List<String> roomIds,
    required DateTime startTime,
    required DateTime endTime,
    int holdMinutes = 10,
  }) async {
    return await callRepository(
      () => _remoteDataSource.acquireBookingHold(
        roomIds: roomIds,
        startTime: startTime,
        endTime: endTime,
        holdMinutes: holdMinutes,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> releaseBookingHold(String holdToken) async {
    return await callRepository<void>(
      () => _remoteDataSource.releaseBookingHold(holdToken),
    );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> quoteBookingCheckout({
    required String holdToken,
    required List<Map<String, dynamic>> roomRequests,
    required List<Map<String, dynamic>> extraItems,
    String? voucherCode,
  }) async {
    return await callRepository(
      () => _remoteDataSource.quoteBookingCheckout(
        holdToken: holdToken,
        roomRequests: roomRequests,
        extraItems: extraItems,
        voucherCode: voucherCode,
      ),
    );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createBookingCheckout({
    required String holdToken,
    required List<Map<String, dynamic>> roomRequests,
    required List<Map<String, dynamic>> extraItems,
    String? voucherCode,
    required String paymentMethod,
    String? senderWalletPhone,
    String? receiptUrl,
  }) async {
    try {
      final res = await _remoteDataSource.createBookingCheckout(
        holdToken: holdToken,
        roomRequests: roomRequests,
        extraItems: extraItems,
        voucherCode: voucherCode,
        paymentMethod: paymentMethod,
        senderWalletPhone: senderWalletPhone,
        receiptUrl: receiptUrl,
      );
      return Right(res);
    } catch (e) {
      if (e.toString().contains('PRICE_CHANGED')) {
        return Left(PriceChangedFailure(
          message: 'تغير سعر الساعات بناءً على القواعد الحالية',
          oldPrice: 0.0,
          newPrice: 0.0,
        ));
      }
      return await callRepository(() => throw e);
    }
  }

  @override
  Future<Either<Failure, BookingPriceQuote>> quoteBookingPrice({
    required String roomId,
    required String date,
    required String startTime,
    required String endTime,
    String playMode = 'single',
    int extraControllers = 0,
    String? couponCode,
  }) async {
    return await callRepository<BookingPriceQuote>(() async {
      final res = await _remoteDataSource.quoteBookingPrice(
        roomId: roomId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        playMode: playMode,
        extraControllers: extraControllers,
        couponCode: couponCode,
      );
      return BookingPriceQuoteModel.fromJson(res);
    });
  }

  @override
  Future<Either<Failure, List<RoomSlotPrice>>> getRoomSlotsWithPrices({
    required String roomId,
    required String date,
  }) async {
    return await callRepository<List<RoomSlotPrice>>(() async {
      final rawList = await _remoteDataSource.getRoomSlotsWithPrices(
        roomId: roomId,
        date: date,
      );
      final slots = rawList
          .map((json) => RoomSlotPriceModel.fromJson(json))
          // Rule requirement: filter out unpriced slots (hourlyRate <= 0)
          .where((slot) => slot.isValidPriced)
          .toList();
      return slots;
    });
  }

  @override
  Future<Either<Failure, LoungePriceRange>> getLoungePriceRange(
    String loungeId,
  ) async {
    return await callRepository<LoungePriceRange>(() async {
      final res = await _remoteDataSource.getLoungePriceRange(loungeId);
      return LoungePriceRangeModel.fromJson(res);
    });
  }

  @override
  Future<Either<Failure, void>> attachBookingReceipt({
    required String bookingId,
    required String receiptPath,
  }) async {
    return await callRepository<void>(
      () => _remoteDataSource.attachBookingReceipt(
        bookingId: bookingId,
        receiptPath: receiptPath,
      ),
    );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createBooking(
    CreateBookingParams params,
  ) async {
    try {
      final res = await _remoteDataSource.createBooking(params);
      return Right(res);
    } catch (e) {
      if (e.toString().contains('PRICE_CHANGED')) {
        return Left(PriceChangedFailure(
          message: 'تغير سعر الساعات بناءً على قواعد الذروة الحالية',
          oldPrice: params.totalPrice,
          newPrice: params.totalPrice,
        ));
      }
      return await callRepository(() => throw e);
    }
  }

  @override
  Stream<BookingModel> watchBookingStatus(String bookingId) {
    return _remoteDataSource.streamBookingStatus(bookingId);
  }

  @override
  Future<Either<Failure, void>> extendSession({
    required String bookingId,
    required int additionalMinutes,
    required double additionalCost,
  }) async {
    return await callRepository(
      () => _remoteDataSource.extendSession(
        bookingId: bookingId,
        additionalMinutes: additionalMinutes,
        additionalCost: additionalCost,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  }) async {
    return await callRepository<void>(
      () => _remoteDataSource.requestExtension(
        bookingId: bookingId,
        requestedMinutes: requestedMinutes,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> callStaff({
    required String loungeId,
    required String bookingId,
    required String reason,
    required String note,
  }) async {
    return await callRepository(
      () => _remoteDataSource.callStaff(
        loungeId: loungeId,
        bookingId: bookingId,
        reason: reason,
        note: note,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> placeCanteenOrder({
    required String bookingId,
    required String loungeId,
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String note,
  }) async {
    return await callRepository(
      () => _remoteDataSource.placeCanteenOrder(
        bookingId: bookingId,
        loungeId: loungeId,
        userId: userId,
        items: items,
        totalPrice: totalPrice,
        note: note,
      ),
    );
  }
}
