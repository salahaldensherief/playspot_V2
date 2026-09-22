import 'dart:developer' as dev;
import 'package:playspot/core/constants/booking_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/booking_params.dart';

abstract class BookingRemoteDataSource {
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date, {String? roomId});
  Future<Map<String, dynamic>> createBooking(CreateBookingParams params);
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
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date, {String? roomId}) async {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    var query = _client
        .from('bookings')
        .select('room_id, start_time, end_time, date, status, start_at, end_at, booking_period')
        .eq('lounge_id', loungeId)
        .eq('date', dateStr);

    if (roomId != null && roomId.isNotEmpty) {
      query = query.eq('room_id', roomId);
    }

    final response = await query;

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<Map<String, dynamic>> createBooking(CreateBookingParams params) async {
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        final profile = await _client
            .from('profiles')
            .select('is_banned, banned_reason')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null && profile['is_banned'] == true) {
          throw Exception('تم حظر حسابك لمخالفة الشروط');
        }

        final loungeBan = await _client
            .from('lounge_banned_users')
            .select('id')
            .eq('lounge_id', params.loungeId)
            .eq('user_id', user.id)
            .maybeSingle();

        if (loungeBan != null) {
          throw Exception('لا يمكنك الحجز في هذه الصالة بناءً على سياسة الإدارة');
        }
      } catch (e) {
        if (e.toString().contains('تم حظر حسابك') || e.toString().contains('لا يمكنك الحجز')) {
          rethrow;
        }
      }
    }
    
    final datePart = "${params.startTime.year}-${params.startTime.month.toString().padLeft(2, '0')}-${params.startTime.day.toString().padLeft(2, '0')}";
    final startPart = "${params.startTime.hour.toString().padLeft(2, '0')}:${params.startTime.minute.toString().padLeft(2, '0')}:${params.startTime.second.toString().padLeft(2, '0')}";
    final endPart = "${params.endTime.hour.toString().padLeft(2, '0')}:${params.endTime.minute.toString().padLeft(2, '0')}:${params.endTime.second.toString().padLeft(2, '0')}";

    final fallbackName = user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString() ??
        '';
    final fallbackPhone = user?.phone ??
        user?.userMetadata?['phone']?.toString() ??
        '';

    final finalUserName = params.userName.isNotEmpty ? params.userName : fallbackName;
    final finalUserPhone = params.userPhone.isNotEmpty ? params.userPhone : fallbackPhone;

    final durationMinutes = params.endTime.difference(params.startTime).inMinutes;

    final String cleanPaymentMethod = (params.paymentMethod?.toLowerCase() == 'cash')
        ? 'cash'
        : 'manual_transfer';

    final bookingPayload = <String, dynamic>{
      'room_id': params.roomId,
      'room_name': params.roomName,
      'lounge_id': params.loungeId,
      'user_id': user?.id,
      'user_name': finalUserName,
      'user_phone': finalUserPhone,
      'date': datePart,
      'start_time': startPart,
      'end_time': endPart,
      'duration_minutes': durationMinutes,
      'original_room_price': params.originalRoomPrice,
      'discounted_room_price': params.discountedRoomPrice,
      'room_price': params.discountedRoomPrice,
      'discount_amount': params.discountAmount,
      'discount_percentage': params.discountPercentage,
      if (params.discountLabel != null) 'discount_label': params.discountLabel,
      if (params.discountReason != null) 'discount_reason': params.discountReason,
      if (params.discountSource != null) 'discount_source': params.discountSource,
      'duration_hours': params.durationHours,
      'room_subtotal': params.roomSubtotal,
      'addons_total': params.addonsTotal,
      'addons_price': params.addonsTotal,
      'total_price': params.totalPrice,
      'status': BookingStatus.mapToDbStatus(params.status),
      'payment_status': params.paymentStatus,
      'play_mode': params.playMode,
      'payment_method': cleanPaymentMethod,
      if (params.receiptUrl != null && params.receiptUrl!.isNotEmpty) 'receipt_url': params.receiptUrl,
      if (cleanPaymentMethod == 'manual_transfer' &&
          params.senderWalletPhone != null &&
          params.senderWalletPhone!.isNotEmpty)
        'sender_wallet_phone': params.senderWalletPhone,
      if (params.expiresAt != null) 'expires_at': params.expiresAt!.toIso8601String(),
    };

    dynamic response;
    try {
      response = await _client.from('bookings').insert(bookingPayload).select('id, is_first_booking, payment_method, status').single();
    } catch (e) {
      // Fallback in case Postgres table doesn't have all optional snapshot columns
      response = await _client.from('bookings').insert({
        'room_id': params.roomId,
        'room_name': params.roomName,
        'lounge_id': params.loungeId,
        'user_id': user?.id,
        'user_name': finalUserName,
        'user_phone': finalUserPhone,
        'date': datePart,
        'start_time': startPart,
        'end_time': endPart,
        'duration_minutes': durationMinutes,
        'total_price': params.totalPrice,
        'room_price': params.discountedRoomPrice,
        if (params.discountAmount > 0) 'discount_amount': params.discountAmount,
        'status': BookingStatus.mapToDbStatus(params.status),
        'payment_status': params.paymentStatus,
        'payment_method': cleanPaymentMethod,
        'play_mode': params.playMode,
        if (cleanPaymentMethod == 'manual_transfer' &&
            params.senderWalletPhone != null &&
            params.senderWalletPhone!.isNotEmpty)
          'sender_wallet_phone': params.senderWalletPhone,
      }).select('id, is_first_booking, payment_method, status').single();
    }

    final bookingId = response['id']?.toString();

    // Call place_canteen_order RPC for canteen/extras items
    if (bookingId != null && params.addOns.isNotEmpty) {
      try {
        final formattedItems = params.addOns.map((e) {
          final id = e['id']?.toString() ?? e['extra_id']?.toString() ?? e['item_id']?.toString() ?? e['product_id']?.toString() ?? '';
          final name = e['name']?.toString() ?? e['title']?.toString() ?? 'Extra';
          final nameAr = e['name_ar']?.toString() ?? name;
          final nameEn = e['name_en']?.toString() ?? name;
          final p = (e['unit_price'] as num?)?.toDouble() ?? (e['price'] as num?)?.toDouble() ?? 0.0;
          final q = (e['quantity'] as num?)?.toInt() ?? 1;

          return {
            'id': id,
            'name_ar': nameAr,
            'name_en': nameEn,
            'unit_price': p,
            'quantity': q,
          };
        }).toList();

        await _client.rpc('place_canteen_order', params: {
          'p_booking_id': bookingId,
          'p_items': formattedItems,
        });
      } catch (e) {
        dev.log("place_canteen_order RPC in createBooking failed: $e");
      }
    }

    return Map<String, dynamic>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> getBookingItems(String bookingId) async {
    try {
      final canteenOrders = await _client
          .from('canteen_orders')
          .select('*, canteen_order_items(*, extras(id, name, name_ar, name_en, price))')
          .eq('booking_id', bookingId);

      final List<Map<String, dynamic>> extractedItems = [];

      for (var cOrder in (canteenOrders as List)) {
        final cItems = cOrder['canteen_order_items'] as List?;
        if (cItems != null) {
          for (var item in cItems) {
            if (item is Map) {
              final extraData = item['extras'] as Map<String, dynamic>?;
              final name = extraData?['name_ar']?.toString() ??
                  extraData?['name']?.toString() ??
                  extraData?['name_en']?.toString() ??
                  item['name']?.toString() ??
                  item['item_name']?.toString() ??
                  'Item';
              final price = (item['unit_price'] as num?)?.toDouble() ??
                  (item['price'] as num?)?.toDouble() ??
                  (extraData?['price'] as num?)?.toDouble() ??
                  0.0;
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              final total = (item['total_price'] as num?)?.toDouble() ?? (price * qty);

              extractedItems.add({
                'id': item['id']?.toString() ?? extraData?['id']?.toString() ?? '',
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
      dev.log("Error querying canteen_orders: $e, falling back to booking_items");
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
      await _client.rpc('extend_booking_session', params: {
        'p_booking_id': bookingId,
        'p_additional_minutes': additionalMinutes,
        'p_additional_cost': additionalCost,
      });
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('BOOKING_EXTENSION_CONFLICT') ||
          errorStr.contains('conflict') ||
          errorStr.contains('23P01') ||
          errorStr.contains('exclusion constraint')) {
        throw Exception("لا يمكن تمديد الحجز لأن هناك حجزاً آخر يبدأ بعد وقت حجزك مباشرة.");
      }
      rethrow;
    }
  }

  @override
  Future<void> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  }) async {
    await _client.from('bookings').update({
      'extension_status': 'pending',
      'requested_extension_minutes': requestedMinutes,
    }).eq('id', bookingId);
  }

  @override
  Future<void> callStaff({
    required String loungeId,
    required String bookingId,
    required String reason,
    required String note,
  }) async {
    final userId = _client.auth.currentUser?.id;

    try {
      await _client.rpc('request_staff_assistance', params: {
        'p_booking_id': bookingId,
        'p_user_id': userId,
        'p_call_type': reason,
        'p_notes': note,
      });
      return;
    } catch (rpc1Error) {
      dev.log("RPC request_staff_assistance failed: $rpc1Error, trying call_staff_request");
    }

    try {
      await _client.rpc('call_staff_request', params: {
        'p_booking_id': bookingId,
        'p_reason': reason,
        'p_note': note,
      });
      return;
    } catch (rpc2Error) {
      dev.log("RPC call_staff_request failed: $rpc2Error, inserting directly into service_calls");
    }

    try {
      // Fetch lounge_id and room_id directly from the booking record using bookingId
      final bookingData = await _client
          .from('bookings')
          .select('lounge_id, room_id, user_id')
          .eq('id', bookingId)
          .maybeSingle();

      final String? fetchedLoungeId = bookingData?['lounge_id']?.toString() ?? (loungeId.isNotEmpty ? loungeId : null);
      final String? roomId = bookingData?['room_id']?.toString();
      final String? bookingUserId = bookingData?['user_id']?.toString() ?? userId;

      await _client.from('service_calls').insert({
        'booking_id': bookingId,
        if (fetchedLoungeId != null && fetchedLoungeId.isNotEmpty) 'lounge_id': fetchedLoungeId,
        if (roomId != null && roomId.isNotEmpty) 'room_id': roomId,
        if (bookingUserId != null && bookingUserId.isNotEmpty) 'user_id': bookingUserId,
        'call_type': reason,
        'status': 'pending',
        if (note.isNotEmpty) 'notes': note,
      });
      dev.log("Inserted directly into service_calls SUCCESS");
    } catch (e) {
      dev.log("callStaff failed to insert into service_calls: $e");
      rethrow;
    }
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
    final validUserId = _client.auth.currentUser?.id ?? userId;
    
    final formattedItems = items.map((item) {
      final id = item['id']?.toString() ?? item['extra_id']?.toString() ?? item['item_id']?.toString() ?? item['product_id']?.toString() ?? '';
      final name = item['name']?.toString() ?? item['title']?.toString() ?? 'Extra';
      final nameAr = item['name_ar']?.toString() ?? name;
      final nameEn = item['name_en']?.toString() ?? name;
      final p = (item['unit_price'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble() ?? 0.0;
      final q = (item['quantity'] as num?)?.toInt() ?? 1;

      return {
        'id': id,
        'name_ar': nameAr,
        'name_en': nameEn,
        'unit_price': p,
        'quantity': q,
      };
    }).toList();

    try {
      final response = await _client.rpc('place_canteen_order', params: {
        'p_booking_id': bookingId,
        'p_items': formattedItems,
      });
      dev.log("place_canteen_order RPC SUCCESS: $response");
    } catch (e) {
      dev.log("place_canteen_order RPC failed: $e, trying full params...");
      try {
        final response = await _client.rpc('place_canteen_order', params: {
          'p_booking_id': bookingId,
          'p_lounge_id': loungeId,
          'p_user_id': validUserId,
          'p_items': formattedItems,
          'p_total_price': totalPrice > 0 ? totalPrice : null,
          'p_note': note.isNotEmpty ? note : null,
        });
        dev.log("place_canteen_order RPC with full params SUCCESS: $response");
      } catch (e2) {
        dev.log("place_canteen_order RPC with full params failed: $e2");
        rethrow;
      }
    }
  }
}
