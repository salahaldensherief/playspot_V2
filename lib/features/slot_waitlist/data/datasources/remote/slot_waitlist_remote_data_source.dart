import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/slot_waitlist_result.dart';

abstract class SlotWaitlistRemoteDataSource {
  Future<SlotWaitlistResult> joinSlotWaitlist({
    required String loungeId,
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay slotTime,
  });
}

class SlotWaitlistRemoteDataSourceImpl implements SlotWaitlistRemoteDataSource {
  final SupabaseClient _client;

  SlotWaitlistRemoteDataSourceImpl(this._client);

  @override
  Future<SlotWaitlistResult> joinSlotWaitlist({
    required String loungeId,
    required List<String> roomIds,
    required DateTime date,
    required TimeOfDay slotTime,
  }) async {
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final timeStr =
        "${slotTime.hour.toString().padLeft(2, '0')}:${slotTime.minute.toString().padLeft(2, '0')}:00";

    // 1. Try single batch RPC first (single intent)
    try {
      final response = await _client.rpc(
        'join_slot_waitlist',
        params: {
          'p_lounge_id': loungeId,
          'p_room_ids': roomIds,
          'p_date': dateStr,
          'p_slot_time': timeStr,
        },
      );
      dev.log("join_slot_waitlist RPC succeeded: $response");
      return SlotWaitlistResult(
        isSuccess: true,
        isPartial: false,
        successfulRoomsCount: roomIds.length,
        failedRoomsCount: 0,
        message: 'notifyMeSuccess',
      );
    } catch (e) {
      dev.log("join_slot_waitlist batch RPC failed ($e), falling back to aggregated rooms request");
    }

    // 2. Multi-room concurrent execution with resilient result aggregation
    if (roomIds.isEmpty) {
      return const SlotWaitlistResult(
        isSuccess: false,
        isPartial: false,
        successfulRoomsCount: 0,
        failedRoomsCount: 0,
        message: 'notifyMeFailure',
      );
    }

    final results = await Future.wait(
      roomIds.map((roomId) async {
        try {
          await _client.rpc(
            'join_room_waitlist',
            params: {
              'p_lounge_id': loungeId,
              'p_room_id': roomId,
              'p_date': dateStr,
              'p_slot_time': timeStr,
            },
          );
          return true;
        } catch (_) {
          try {
            final user = _client.auth.currentUser;
            if (user != null) {
              await _client.from('slot_waitlist').insert({
                'user_id': user.id,
                'lounge_id': loungeId,
                'room_id': roomId,
                'date': dateStr,
                'slot_time': timeStr,
              });
              return true;
            }
          } catch (_) {}
          return false;
        }
      }),
    );

    final successCount = results.where((r) => r == true).length;
    final failedCount = results.length - successCount;

    if (successCount > 0) {
      return SlotWaitlistResult(
        isSuccess: true,
        isPartial: failedCount > 0,
        successfulRoomsCount: successCount,
        failedRoomsCount: failedCount,
        message: failedCount > 0 ? 'notifyMePartial' : 'notifyMeSuccess',
      );
    }

    throw Exception('Failed to join waitlist for all rooms');
  }
}
