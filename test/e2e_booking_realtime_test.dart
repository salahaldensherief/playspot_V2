// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Complete E2E Realtime Booking Flow: Hold -> Checkout -> Start -> Realtime -> Complete -> Realtime', () async {
    final configFile = File(Platform.environment['LOCAL_SUPABASE_CONFIG'] ?? 'C:/Users/salah/Documents/Codex/2026-10-08/files-pasted-by-the-user-playspot/work/isolated-supabase/local-status.private.json');
    if (!configFile.existsSync()) {
      print('Skipping E2E test in environment without local isolated Supabase.');
      return;
    }
    final accountsFile = File('C:/Users/salah/Documents/Codex/2026-10-08/files-pasted-by-the-user-playspot/work/isolated-supabase/test-accounts.private.json');
    final seedFile = File('C:/Users/salah/Documents/Codex/2026-10-08/files-pasted-by-the-user-playspot/work/isolated-supabase/synthetic-seed-manifest.json');

    final config = jsonDecode(await configFile.readAsString());
    final List<dynamic> accounts = jsonDecode(await accountsFile.readAsString());
    final seed = jsonDecode(await seedFile.readAsString());

    final userAcc = accounts.firstWhere((a) => a['role'] == 'user');
    final cashierAcc = accounts.firstWhere((a) => a['role'] == 'cashier');
    final loungeId = seed['lounge'] as String;
    final roomId = seed['room'] as String;
    final deviceId = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';

    final supabaseUrl = config['API_URL'] as String;
    final anonKey = config['ANON_KEY'] as String;

    // 1. Initialize Supabase Cashier client to renew heartbeat
    final cashierClient = SupabaseClient(supabaseUrl, anonKey);
    await cashierClient.auth.setSession(cashierAcc['refresh_token']);

    final refreshRes = await cashierClient.rpc('refresh_cashier_writer', params: {
      'p_lounge_id': loungeId,
      'p_device_id': deviceId,
      'p_online': true,
    });
    expect(refreshRes, isNotNull);
    print('Cashier heartbeat refreshed: ${refreshRes['heartbeat_expires_at']}');

    // 2. Initialize Supabase User client
    final userClient = SupabaseClient(supabaseUrl, anonKey);
    await userClient.auth.setSession(userAcc['refresh_token']);

    // Use unique dynamic start time slot in the future to avoid any collision
    final now = DateTime.now().toUtc();
    final uniqueHourOffset = 48 + ((DateTime.now().millisecondsSinceEpoch ~/ 1000) % 150);
    final start = DateTime.utc(now.year, now.month, now.day).add(Duration(hours: uniqueHourOffset));
    final end = start.add(const Duration(hours: 2));

    final startAtStr = start.toIso8601String().substring(0, 19);
    final endAtStr = end.toIso8601String().substring(0, 19);

    print('Acquiring hold for room: $roomId from $startAtStr to $endAtStr');
    final holdRes = await userClient.rpc('acquire_booking_hold', params: {
      'p_room_ids': [roomId],
      'p_start_at': startAtStr,
      'p_end_at': endAtStr,
      'p_hold_minutes': 10,
    });

    expect(holdRes['success'], true);
    final holdToken = holdRes['hold_token'] as String;
    print('Hold acquired token: $holdToken');

    // 3. Quote checkout
    final roomRequests = [
      {
        'room_id': roomId,
        'start_at': startAtStr,
        'end_at': endAtStr,
        'play_mode': 'single',
        'extra_controllers': 0,
      }
    ];

    final quoteRes = await userClient.rpc('quote_my_booking_checkout', params: {
      'p_hold_token': holdToken,
      'p_room_requests': roomRequests,
      'p_extra_items': [],
      'p_voucher_code': null,
    });
    expect(quoteRes['success'], true);
    expect(quoteRes['final_total'], 200);
    print('Checkout quoted: final_total = ${quoteRes['final_total']}');

    // 4. Create checkout
    final checkoutRes = await userClient.rpc('create_my_booking_checkout', params: {
      'p_hold_token': holdToken,
      'p_room_requests': roomRequests,
      'p_extra_items': [],
      'p_voucher_code': null,
      'p_payment_method': 'cash',
      'p_sender_wallet_phone': null,
      'p_receipt_url': null,
    });
    expect(checkoutRes['success'], true);
    final bookingId = (checkoutRes['booking_ids'] as List).first as String;
    print('Booking created: $bookingId');

    // 5. Subscribe to Realtime events on this booking
    final completerStarted = Completer<String>();
    final completerCompleted = Completer<String>();

    final channel = userClient.channel('booking-watch-$bookingId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bookings',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: bookingId,
        ),
        callback: (payload) {
          final newRecord = payload.newRecord;
          final status = newRecord['status'] as String?;
          print('>>> Realtime event received: ${payload.eventType} -> status: $status');
          if (status == 'in_progress' && !completerStarted.isCompleted) {
            completerStarted.complete(status);
          } else if (status == 'completed' && !completerCompleted.isCompleted) {
            completerCompleted.complete(status);
          }
        },
      );

    channel.subscribe();
    // Allow channel connection to establish
    await Future.delayed(const Duration(seconds: 3));

    // 6. Cashier completes cash payment and starts booking session
    print('Cashier completing cash payment for booking $bookingId...');
    final paymentRes = await cashierClient.rpc('complete_booking_payment', params: {
      'p_booking_id': bookingId,
      'p_payment_method': 'cash',
    });
    expect(paymentRes['success'], true);
    print('Cash payment completed: amount ${paymentRes['amount_paid']} on shift ${paymentRes['shift_id']}!');

    print('Cashier starting session for booking $bookingId...');
    final startSessionRes = await cashierClient.rpc('start_booking_session', params: {
      'p_booking_id': bookingId,
    });
    print('Session start result: $startSessionRes');

    final startedStatus = await completerStarted.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => 'TIMEOUT',
    );
    expect(startedStatus, 'in_progress');
    print('VERIFIED: Realtime notified Mobile of session start (in_progress)!');

    // 7. Cashier completes booking session
    print('Cashier completing session for booking $bookingId...');
    final completeSessionRes = await cashierClient.rpc('update_booking_status_admin', params: {
      'p_booking_id': bookingId,
      'p_status': 'completed',
    });
    print('Session complete result: $completeSessionRes');

    final completedStatus = await completerCompleted.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => 'TIMEOUT',
    );
    expect(completedStatus, 'completed');
    print('VERIFIED: Realtime notified Mobile of session completion (completed)!');

    await userClient.removeChannel(channel);
    print('ALL REALTIME E2E STEPS VERIFIED SUCCESSFULLY!');
  });
}
