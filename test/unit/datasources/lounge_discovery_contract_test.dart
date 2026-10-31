import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/home/data/datasources/remote/home_remote_data_source.dart';
import 'package:playspot/features/home/data/models/home_params.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'real Supabase transport keeps RPC names, coordinate order and filters',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'fixture-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });
      final received = server.first.then((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/rest/v1/rpc/discover_lounges');
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode([
            {
              'id': 'l',
              'distance_km': 3.97464437794,
              'location_point': 'SRID=4326;POINT(31.2357 30.0444)',
            },
          ]),
        );
        await request.response.close();
        return body;
      });
      const params = GetLoungesParams(
        lat: 30.0131,
        lng: 31.2156,
        city: 'Cairo',
        categoryIds: ['category-id'],
        sortType: 'nearest',
        isOpenOnly: true,
        limit: 10,
        offset: 20,
      );
      final lounges = await HomeRemoteDataSourceImpl(client).getLounges(params);
      expect(await received, {
        'p_lat': 30.0131,
        'p_lng': 31.2156,
        'p_city': 'Cairo',
        'p_search_query': null,
        'p_category_ids': ['category-id'],
        'p_sort_type': 'nearest',
        'p_is_open_only': true,
        'p_limit': 10,
        'p_offset': 20,
      });
      expect(lounges.single.lat, 30.0444);
      expect(lounges.single.lng, 31.2357);
      expect(lounges.single.distance, 3.97464437794);
      expect(lounges.single.getFormattedDistance(isArabic: true), '4.0 كم');
    },
  );

  for (final point in <List<double?>>[
    [null, null],
    [null, 31],
    [30, null],
    [91, 31],
    [30, 181],
    [double.nan, 31],
  ]) {
    test(
      'invalid or incomplete user location $point sends no invented position',
      () {
        final json = GetLoungesParams(lat: point[0], lng: point[1]).toJson();
        expect(json['p_lat'], isNull);
        expect(json['p_lng'], isNull);
      },
    );
  }
  test('equator and Greenwich are legitimate coordinates, not missing GPS', () {
    final json = const GetLoungesParams(lat: 0, lng: 0).toJson();
    expect(json['p_lat'], 0);
    expect(json['p_lng'], 0);
  });
}
