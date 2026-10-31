import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/features/lounge_details/data/datasources/remote/lounge_details_remote_data_source.dart';

void main() {
  for (final status in [403, 503]) {
    test(
      'room request failure $status remains failure after fallback',
      () async {
        final client = SupabaseClient(
          'https://fixture.invalid',
          'synthetic-key',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'code': status == 403 ? '42501' : 'XX000',
                'message': 'Synthetic failure',
              }),
              status,
              headers: {'content-type': 'application/json'},
              request: request,
            ),
          ),
        );
        addTearDown(client.dispose);
        await expectLater(
          LoungeDetailsRemoteDataSourceImpl(client).getRoomById('room'),
          throwsA(isA<PostgrestException>()),
        );
      },
    );
  }
  test('a successful no-row response is still confirmed missing', () async {
    final client = SupabaseClient(
      'https://fixture.invalid',
      'synthetic-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    expect(
      await LoungeDetailsRemoteDataSourceImpl(client).getRoomById('room'),
      isNull,
    );
  });
}
