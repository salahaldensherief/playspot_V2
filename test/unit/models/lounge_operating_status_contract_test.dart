import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/features/lounge_details/data/datasources/remote/lounge_details_remote_data_source.dart';

void main() {
  test(
    'operating status RPC preserves lounge scope and actual phone',
    () async {
      final client = SupabaseClient(
        'https://example.invalid',
        'fixture-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/get_lounge_operating_status');
          expect(jsonDecode(request.body), {'p_lounge_id': 'venue-1'});
          return http.Response(
            jsonEncode({
              'status': 'technical_issue',
              'can_book_online': false,
              'contact_phone': '01012345678',
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await LoungeDetailsRemoteDataSourceImpl(
        client,
      ).getLoungeOperatingStatus('venue-1');
      expect(result?.isTechnicalIssue, isTrue);
      expect(result?.canBookOnline, isFalse);
      expect(result?.contactPhone, '01012345678');
    },
  );
  test(
    'missing RPC remains a failure instead of an open-lounge fallback',
    () async {
      final client = SupabaseClient(
        'https://example.invalid',
        'fixture-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'code': 'PGRST202', 'message': 'Unavailable'}),
            404,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        LoungeDetailsRemoteDataSourceImpl(
          client,
        ).getLoungeOperatingStatus('venue-1'),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
  test('empty status response is not treated as a successful fetch', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'fixture-key',
      httpClient: MockClient(
        (request) async => http.Response(
          'null',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      LoungeDetailsRemoteDataSourceImpl(
        client,
      ).getLoungeOperatingStatus('venue-1'),
      throwsFormatException,
    );
  });
}
