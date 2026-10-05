import 'dart:developer' as dev;
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class BookingRemoteDataSource {
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(
    String loungeId,
    DateTime date, {
    String? roomId,
  });
  Future<bool> checkRoomAvailability({
    required String roomId,
    required DateTime startTime,
    required DateTime endTime,
  });
  Future<Map<String, dynamic>> acquireBookingHold({
    required List<String> roomIds,
    required DateTime startTime,
    required DateTime endTime,
    int holdMinutes = 10,
  });
  Future<void> releaseBookingHold(String holdToken);
  Future<Map<String, dynamic>> quoteBookingCheckout({
    required String holdToken,
    required List<Map<String, dynamic>> roomRequests,
    required List<Map<String, dynamic>> extraItems,
    String? voucherCode,
  });
  Future<Map<String, dynamic>> createBookingCheckout({
    required String holdToken,
    required List<Map<String, dynamic>> roomRequests,
    required List<Map<String, dynamic>> extraItems,
    String? voucherCode,
    required String paymentMethod,
    String? senderWalletPhone,
    String? receiptUrl,
  });
  Future<Map<String, dynamic>> quoteBookingPrice({
    required String roomId,
    required String date,
    required String startTime,
    required String endTime,
    String playMode = 'single',
    int extraControllers = 0,
    String? couponCode,
  });
  Future<List<Map<String, dynamic>>> getRoomSlotsWithPrices({
    required String roomId,
    required String date,
  });
  Future<Map<String, dynamic>> getLoungePriceRange(String loungeId);
  Future<void> attachBookingReceipt({
    required String bookingId,
    required String receiptPath,
  });
  Stream<BookingModel> streamBookingStatus(String bookingId);
  Future<List<Map<String, dynamic>>> getBookingItems(String bookingId);
  Future<void> extendSession({
    required String bookingId,
    required int additionalMinutes,
    required double additionalCost,
  });
  Future<void> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  });
  Future<void> callStaff({
    required String loungeId,
    required String bookingId,
    required String reason,
    required String note,
  });
  Future<void> placeCanteenOrder({
    required String bookingId,
    required String loungeId,
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String note,
  });
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final SupabaseClient _client;

  BookingRemoteDataSourceImpl(this._client);

  @override
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(
    String loungeId,
    DateTime date, {
    String? roomId,
  }) async {
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final response = await _client.rpc(
      'get_room_bookings_for_operational_date',
      params: {'p_lounge_id': loungeId, 'p_date': dateStr},
    );

    final rows = List<Map<String, dynamic>>.from(response as List);
    if (roomId == null || roomId.isEmpty) return rows;

    return rows.where((row) => row['room_id']?.toString() == roomId).toList();
  }

  @override
  Future<bool> checkRoomAvailability({
    required String roomId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final response = await _client.rpc(
      'check_room_availability_local',
      params: {
        'p_room_id': roomId,
        'p_start_time': startTime.toIso8601String(),
        'p_end_time': endTime.toIso8601String(),
      },
    );

    return response == true;
  }

  @override
  Future<Map<String, dynamic>> acquireBookingHold({
    required List<String> roomIds,
    required DateTime startTime,
    required DateTime endTime,
    int holdMinutes = 10,
  }) async {
    final response = await _client.rpc(
      'acquire_booking_hold',
      params: {
        'p_room_ids': roomIds,
        'p_start_at': startTime.toIso8601String(),
        'p_end_at': endTime.toIso8601String(),
        'p_hold_minutes': holdMinutes,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  @override
  Future<void> releaseBookingHold(String holdToken) async {
    await _client.rpc(
      'release_booking_hold',
      params: {'p_hold_token': holdToken},
    );
  }

  @override
  Future<Map<String, dynamic>> quoteBookingCheckout({
    required String holdToken,
    required List<Map<String, dynamic>> roomRequests,
    required List<Map<String, dynamic>> extraItems,
    String? voucherCode,
  }) async {
    final response = await _client.rpc(
      'quote_my_booking_checkout',
      params: {
        'p_hold_token': holdToken,
        'p_room_requests': roomRequests,
        'p_extra_items': extraItems,
        'p_voucher_code': voucherCode,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  @override
  Future<Map<String, dynamic>> createBookingCheckout({
    required String holdToken,
    required List<Map<String, dynamic>> roomRequests,
    required List<Map<String, dynamic>> extraItems,
    String? voucherCode,
    required String paymentMethod,
    String? senderWalletPhone,
    String? receiptUrl,
  }) async {
    try {
      final response = await _client.rpc(
        'create_my_booking_checkout',
        params: {
          'p_hold_token': holdToken,
          'p_room_requests': roomRequests,
          'p_extra_items': extraItems,
          'p_voucher_code': voucherCode,
          'p_payment_method': paymentMethod,
          'p_sender_wallet_phone': senderWalletPhone,
          'p_receipt_url': receiptUrl,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      _checkPriceChangedError(e);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> quoteBookingPrice({
    required String roomId,
    required String date,
    required String startTime,
    required String endTime,
    String playMode = 'single',
    int extraControllers = 0,
    String? couponCode,
  }) async {
    final response = await _client.rpc(
      'quote_booking_price',
      params: {
        'p_room_id': roomId,
        'p_date': date,
        'p_start': startTime,
        'p_end': endTime,
        'p_play_mode': playMode,
        'p_extra_controllers': extraControllers,
        'p_coupon_code': couponCode,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> getRoomSlotsWithPrices({
    required String roomId,
    required String date,
  }) async {
    final response = await _client.rpc(
      'get_room_slots_with_prices',
      params: {'p_room_id': roomId, 'p_date': date},
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<Map<String, dynamic>> getLoungePriceRange(String loungeId) async {
    final response = await _client.rpc(
      'get_lounge_price_range',
      params: {'p_lounge_id': loungeId},
    );

    return Map<String, dynamic>.from(response as Map);
  }

  void _checkPriceChangedError(dynamic error) {
    final errStr = error.toString();
    if (errStr.contains('PRICE_CHANGED') ||
        (error is PostgrestException && error.code == 'PRICE_CHANGED')) {
      throw Exception('PRICE_CHANGED: $errStr');
    }
  }

  @override
  Future<void> attachBookingReceipt({
    required String bookingId,
    required String receiptPath,
  }) async {
    await _client.rpc(
      'attach_my_booking_receipt',
      params: {'p_booking_id': bookingId, 'p_receipt_url': receiptPath},
    );
  }

  @override
  Stream<BookingModel> streamBookingStatus(String bookingId) {
    return _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId)
        .map((list) {
          if (list.isNotEmpty) {
            return BookingModel.fromJson(list.first);
          }
          throw Exception('Booking record not found');
        });
  }

  @override
  Future<List<Map<String, dynamic>>> getBookingItems(String bookingId) async {
    try {
      final canteenOrders = await _client
          .from('canteen_orders')
          .select(
            '*, canteen_order_items(*, extras(id, name, name_ar, name_en, price))',
          )
          .eq('booking_id', bookingId);

      final List<Map<String, dynamic>> extractedItems = [];

      for (var cOrder in (canteenOrders as List)) {
        final cItems = cOrder['canteen_order_items'] as List?;
        if (cItems != null) {
          for (var item in cItems) {
            if (item is Map) {
              final extraData = item['extras'] as Map<String, dynamic>?;
              final name =
                  extraData?['name_ar']?.toString() ??
                  extraData?['name']?.toString() ??
                  extraData?['name_en']?.toString() ??
                  item['name']?.toString() ??
                  item['item_name']?.toString() ??
                  'Item';
              final price =
                  (item['unit_price'] as num?)?.toDouble() ??
                  (item['price'] as num?)?.toDouble() ??
                  (extraData?['price'] as num?)?.toDouble() ??
                  0.0;
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              final total =
                  (item['total_price'] as num?)?.toDouble() ?? (price * qty);

              extractedItems.add({
                'id':
                    item['id']?.toString() ??
                    extraData?['id']?.toString() ??
                    '',
                'name': name,
                'quantity': qty,
                'unit_price': price,
                'price': price,
                'total_price': total,
                'note': item['note']?.toString() ?? cOrder['notes']?.toString(),
              });
            }
          }
        }
      }

      if (extractedItems.isNotEmpty) return extractedItems;
    } catch (e) {
      dev.log(
        "Error querying canteen_orders: $e, falling back to booking_items",
      );
    }

    final response = await _client
        .from('booking_items')
        .select('*')
        .eq('booking_id', bookingId);

    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<void> extendSession({
    required String bookingId,
    required int additionalMinutes,
    required double additionalCost,
  }) async {
    try {
      await _client.rpc(
        'extend_booking_session',
        params: {
          'p_booking_id': bookingId,
          'p_additional_minutes': additionalMinutes,
          'p_additional_cost': additionalCost,
        },
      );
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('BOOKING_EXTENSION_CONFLICT') ||
          errorStr.contains('conflict') ||
          errorStr.contains('23P01') ||
          errorStr.contains('exclusion constraint')) {
        throw Exception(
          "لا يمكن تمديد الحجز لأن هناك حجزاً آخر يبدأ بعد وقت حجزك مباشرة.",
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  }) async {
    await _client.rpc(
      'request_booking_extension',
      params: {
        'p_booking_id': bookingId,
        'p_requested_minutes': requestedMinutes,
      },
    );
  }

  @override
  Future<void> callStaff({
    required String loungeId,
    required String bookingId,
    required String reason,
    required String note,
  }) async {
    await _client.rpc(
      'request_staff_assistance_for_booking',
      params: {
        'p_booking_id': bookingId,
        'p_call_type': reason,
        'p_notes': note.isEmpty ? null : note,
      },
    );
  }

  @override
  Future<void> placeCanteenOrder({
    required String bookingId,
    required String loungeId,
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String note,
  }) async {
    final formattedItems = items.map((item) {
      final id =
          item['id']?.toString() ??
          item['extra_id']?.toString() ??
          item['item_id']?.toString() ??
          item['product_id']?.toString() ??
          '';
      final name =
          item['name']?.toString() ?? item['title']?.toString() ?? 'Extra';
      final nameAr = item['name_ar']?.toString() ?? name;
      final nameEn = item['name_en']?.toString() ?? name;
      final p =
          (item['unit_price'] as num?)?.toDouble() ??
          (item['price'] as num?)?.toDouble() ??
          0.0;
      final q = (item['quantity'] as num?)?.toInt() ?? 1;

      return {
        'id': id,
        'extra_id': id,
        'item_id': id,
        'product_id': id,
        'name_ar': nameAr,
        'name_en': nameEn,
        'unit_price': p,
        'price': p,
        'quantity': q,
      };
    }).toList();

    final response = await _client.rpc(
      'place_canteen_order',
      params: {
        'p_booking_id': bookingId,
        'p_items': formattedItems,
        'p_note': note.isEmpty ? null : note,
      },
    );
    dev.log("place_canteen_order RPC SUCCESS: $response");
  }
}
