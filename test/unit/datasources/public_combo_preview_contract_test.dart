import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playspot/features/lounge_details/data/datasources/remote/lounge_details_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('anonymous lounge preview uses only read-only public combo RPC', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.invalid',
      'anon-test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode([
            {
              'id': 'public-offer',
              'name_ar': 'باقة الأصدقاء',
              'price': 84.6,
              'separate_items_price': 105,
              'savings': 20.4,
              'is_available': true,
              'items': [
                {
                  'extra_id': 'water',
                  'name_ar': 'مياه',
                  'price': 18,
                  'quantity': 2,
                },
              ],
            },
            {
              'id': 'hidden',
              'name_ar': 'غير متاح',
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

    final source = LoungeDetailsRemoteDataSourceImpl(client);
    final offers = await source.getPublicCanteenCombos('lounge-1');

    expect(offers, hasLength(1));
    expect(offers.single.nameAr, 'باقة الأصدقاء');
    expect(offers.single.savings, 20.4);
    expect(offers.single.items.single.quantity, 2);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/rest/v1/rpc/get_public_canteen_combos');
    expect(jsonDecode(requests.single.body), {'p_lounge_id': 'lounge-1'});
    expect(requests.single.headers.containsKey('authorization'), isTrue);
  });

  test('public combo read failures remain visible to callers', () async {
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
