import 'dart:developer' as dev;
import 'package:playspot/core/constants/booking_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/booking_params.dart';

abstract class BookingRemoteDataSource {
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date);
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
  Future<List<Map<String, dynamic>>> getRoomBookingsForDate(String loungeId, DateTime date) async {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    final response = await _client
        .from('bookings')
        .select('room_id, start_time, end_time, date, status, start_at, end_at')
        .eq('lounge_id', loungeId)
        .eq('date', dateStr);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<Map<String, dynamic>> createBooking(CreateBookingParams params) async {
    final user = _client.auth.currentUser;
    
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

    // Insert core booking
    final response = await _client.from('bookings').insert({
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
      'room_price': params.roomPrice,
      if (params.discountAmount > 0) 'discount_amount': params.discountAmount,
      'status': BookingStatus.mapToDbStatus(params.status),
      'payment_status': params.paymentStatus,
      'play_mode': params.playMode,
    }).select('id').single();

    final bookingId = response['id']?.toString();

    // Directly insert canteen/extras items into booking_items table
    if (bookingId != null && params.addOns.isNotEmpty) {
      try {
        final itemsToInsert = params.addOns.map((e) {
          final id = e['id']?.toString() ?? e['extra_id']?.toString() ?? e['item_id']?.toString() ?? e['product_id']?.toString();
          final name = e['name']?.toString() ?? e['title']?.toString() ?? 'Extra';
          final p = (e['price'] as num?)?.toDouble() ?? 0.0;
          final q = (e['quantity'] as num?)?.toInt() ?? 1;
          final totalP = p * q;
          final note = e['note']?.toString();

          return {
            'booking_id': bookingId,
            if (id != null && id.isNotEmpty) 'product_id': id,
            if (id != null && id.isNotEmpty) 'item_id': id,
            if (id != null && id.isNotEmpty) 'extra_id': id,
            'name': name,
            'quantity': q,
            'price': p,
            'unit_price': p,
            'total_price': totalP,
            if (note != null && note.isNotEmpty) 'note': note,
          };
        }).toList();

        await _client.from('booking_items').insert(itemsToInsert);
      } catch (e) {
        dev.log("Error inserting booking_items: $e");
      }
    }

    return Map<String, dynamic>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> getBookingItems(String bookingId) async {
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
        'p_added_cost': additionalCost,
      });
    } catch (e) {
      try {
        final booking = await _client.from('bookings').select('end_time, extensions_price, total_price').eq('id', bookingId).single();
        final rawEnd = booking['end_time']?.toString() ?? '';
        DateTime currentEnd;
        if (rawEnd.contains('T')) {
          currentEnd = DateTime.parse(rawEnd);
        } else if (rawEnd.contains(':')) {
          final parts = rawEnd.split(':');
          final now = DateTime.now();
          currentEnd = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]), parts.length > 2 ? int.parse(parts[2].split('.')[0]) : 0);
        } else {
          currentEnd = DateTime.now();
        }
        final newEnd = currentEnd.add(Duration(minutes: additionalMinutes));
        final newEndStr = "${newEnd.hour.toString().padLeft(2, '0')}:${newEnd.minute.toString().padLeft(2, '0')}:${newEnd.second.toString().padLeft(2, '0')}";
        final currentExtPrice = (booking['extensions_price'] as num?)?.toDouble() ?? 0.0;
        final currentTotal = (booking['total_price'] as num?)?.toDouble() ?? 0.0;

        await _client.from('bookings').update({
          'end_time': newEndStr,
          'extensions_price': currentExtPrice + additionalCost,
          'total_price': currentTotal + additionalCost,
        }).eq('id', bookingId);
      } catch (fallbackError) {
        rethrow;
      }
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
    final itemsToInsert = items.map((item) {
      final id = item['id']?.toString() ?? item['extra_id']?.toString() ?? item['item_id']?.toString() ?? item['product_id']?.toString();
      final name = item['name']?.toString() ?? item['title']?.toString() ?? 'Extra';
      final p = (item['price'] as num?)?.toDouble() ?? 0.0;
      final q = (item['quantity'] as num?)?.toInt() ?? 1;
      final totalP = p * q;

      return {
        'booking_id': bookingId,
        if (id != null && id.isNotEmpty) 'product_id': id,
        if (id != null && id.isNotEmpty) 'item_id': id,
        if (id != null && id.isNotEmpty) 'extra_id': id,
        'name': name,
        'quantity': q,
        'price': p,
        'unit_price': p,
        'total_price': totalP,
        if (note.isNotEmpty) 'note': note,
      };
    }).toList();

    try {
      await _client.from('booking_items').insert(itemsToInsert);
    } catch (_) {
      await _client.rpc('place_canteen_order', params: {
        'p_booking_id': bookingId,
        'p_lounge_id': loungeId,
        'p_user_id': validUserId,
        'p_items': items,
        'p_total_price': totalPrice,
        'p_note': note,
      });
    }
  }
}
