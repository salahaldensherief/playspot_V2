import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final configPath = Platform.environment['LOCAL_SUPABASE_CONFIG'];
  test(
    'Complete E2E Realtime Booking Flow: Hold -> Checkout -> Start -> Realtime -> Complete -> Realtime',
    () async {
      final configFile = File(configPath!);
      final fixtureDirectory = configFile.parent;
      final accountsFile = File(
        '${fixtureDirectory.path}/test-accounts.private.json',
      );
      final seedFile = File(
        '${fixtureDirectory.path}/synthetic-seed-manifest.json',
      );
      for (final file in [configFile, accountsFile, seedFile]) {
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Missing local E2E fixture: ${file.path}',
        );
      }
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final accounts =
          jsonDecode(await accountsFile.readAsString()) as List<dynamic>;
      final seed =
          jsonDecode(await seedFile.readAsString()) as Map<String, dynamic>;
      final endpoint = Uri.parse(config['API_URL'] as String);
      expect(
        endpoint.scheme,
        'http',
        reason: 'E2E mutations require the isolated local stack',
      );
      expect(
        ['127.0.0.1', 'localhost', '::1'],
        contains(endpoint.host),
        reason: 'E2E must never mutate a hosted project',
      );

      final userAcc = accounts.firstWhere((a) => a['role'] == 'user');
      final cashierAcc = accounts.firstWhere((a) => a['role'] == 'cashier');
      final loungeId = seed['lounge'] as String;
      final roomId = seed['room'] as String;
      final deviceId = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';

      final supabaseUrl = config['API_URL'] as String;
      final anonKey = config['ANON_KEY'] as String;

      final cashierClient = SupabaseClient(supabaseUrl, anonKey);
      addTearDown(cashierClient.dispose);
      await cashierClient.auth.setSession(cashierAcc['refresh_token']);

      final refreshRes = await cashierClient.rpc(
        'refresh_cashier_writer',
        params: {
          'p_lounge_id': loungeId,
          'p_device_id': deviceId,
          'p_online': true,
        },
      );
      expect(refreshRes, isNotNull);

      final userClient = SupabaseClient(supabaseUrl, anonKey);
      addTearDown(userClient.dispose);
      await userClient.auth.setSession(userAcc['refresh_token']);

      final now = DateTime.now().toUtc();
      final uniqueHourOffset =
          48 + ((DateTime.now().millisecondsSinceEpoch ~/ 1000) % 150);
      final start = DateTime.utc(
        now.year,
        now.month,
        now.day,
      ).add(Duration(hours: uniqueHourOffset));
      final end = start.add(const Duration(hours: 2));

      final startAtStr = start.toIso8601String().substring(0, 19);
      final endAtStr = end.toIso8601String().substring(0, 19);

      final holdRes = await userClient.rpc(
        'acquire_booking_hold',
        params: {
          'p_room_ids': [roomId],
          'p_start_at': startAtStr,
          'p_end_at': endAtStr,
          'p_hold_minutes': 10,
        },
      );

      expect(holdRes['success'], true);
      final holdToken = holdRes['hold_token'] as String;

      final roomRequests = [
        {
          'room_id': roomId,
          'start_at': startAtStr,
          'end_at': endAtStr,
          'play_mode': 'single',
          'extra_controllers': 0,
        },
      ];

      final quoteRes = await userClient.rpc(
        'quote_my_booking_checkout',
        params: {
          'p_hold_token': holdToken,
          'p_room_requests': roomRequests,
          'p_extra_items': [],
          'p_voucher_code': null,
        },
      );
      expect(quoteRes['success'], true);
      expect(quoteRes['final_total'], 200);

      final checkoutRes = await userClient.rpc(
        'create_my_booking_checkout',
        params: {
          'p_hold_token': holdToken,
          'p_room_requests': roomRequests,
          'p_extra_items': [],
          'p_voucher_code': null,
          'p_payment_method': 'cash',
          'p_sender_wallet_phone': null,
          'p_receipt_url': null,
        },
      );
      expect(checkoutRes['success'], true);
      final bookingId = (checkoutRes['booking_ids'] as List).first as String;

      final completerStarted = Completer<String>();
      final completerCompleted = Completer<String>();

      final channel = userClient
          .channel('booking-watch-$bookingId')
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
              if (status == 'in_progress' && !completerStarted.isCompleted) {
                completerStarted.complete(status);
              } else if (status == 'completed' &&
                  !completerCompleted.isCompleted) {
                completerCompleted.complete(status);
              }
            },
          );

      addTearDown(() => userClient.removeChannel(channel));
      final subscribed = Completer<void>();
      channel.subscribe((status, error) {
        if (subscribed.isCompleted) return;
        if (status == RealtimeSubscribeStatus.subscribed) {
          subscribed.complete();
        } else if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut ||
            status == RealtimeSubscribeStatus.closed) {
          subscribed.completeError(
            StateError('Realtime subscription failed: $status'),
          );
        }
      });
      await subscribed.future.timeout(const Duration(seconds: 15));

      final paymentRes = await cashierClient.rpc(
        'complete_booking_payment',
        params: {'p_booking_id': bookingId, 'p_payment_method': 'cash'},
      );
      expect(paymentRes['success'], true);

      await cashierClient.rpc(
        'start_booking_session',
        params: {'p_booking_id': bookingId},
      );

      final startedStatus = await completerStarted.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => 'TIMEOUT',
      );
      expect(startedStatus, 'in_progress');

      await cashierClient.rpc(
        'update_booking_status_admin',
        params: {'p_booking_id': bookingId, 'p_status': 'completed'},
      );

      final completedStatus = await completerCompleted.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => 'TIMEOUT',
      );
      expect(completedStatus, 'completed');
    },
    skip: configPath == null
        ? 'Set LOCAL_SUPABASE_CONFIG to explicitly run local Auth/Realtime E2E'
        : false,
    tags: ['live'],
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
