import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playspot/features/lounge_details/data/datasources/remote/lounge_details_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('public combo preview calls the read-only RPC', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.invalid',
      'anon-test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode([
            {
              'id': 'offer',
              'name_ar': 'Combo',
              'price': 84.6,
              'separate_items_price': 105,
              'savings': 20.4,
              'is_available': true,
              'items': [],
            },
            {
              'id': 'unavailable',
              'name_ar': 'Hidden',
              'price': 80,
              'is_available': false,
              'items': [],
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final offers = await LoungeDetailsRemoteDataSourceImpl(
      client,
    ).getPublicCanteenCombos('lounge-1');

    expect(offers, hasLength(1));
    expect(offers.single.nameAr, 'Combo');
    expect(offers.single.savings, 20.4);
    expect(requests, hasLength(1));
    final sent = requests.single;
    expect(sent.method, 'POST');
    expect(sent.url.path, '/rest/v1/rpc/get_public_canteen_combos');
    expect(jsonDecode(sent.body), {'p_lounge_id': 'lounge-1'});
  });

  test('public combo read failures propagate', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'anon-test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '{"message":"Denied","code":"42501"}',
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    final source = LoungeDetailsRemoteDataSourceImpl(client);
    await expectLater(
      source.getPublicCanteenCombos('lounge-1'),
      throwsA(isA<PostgrestException>()),
    );
  });
}
