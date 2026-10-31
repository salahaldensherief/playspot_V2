import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/features/auth/data/datasources/remote/auth_profile_initializer.dart';

void main() {
  const userId = '00000000-0000-0000-0000-000000000001';
  final user = User.fromJson({
    'id': userId,
    'aud': 'authenticated',
    'email': 'customer@example.invalid',
    'created_at': '2026-10-01T00:00:00Z',
    'user_metadata': {
      'full_name': 'Initial name',
      'avatar_url': 'initial-avatar',
    },
    'app_metadata': {'provider': 'email'},
  })!;
  late SupabaseClient client;
  late List<http.Request> requests;
  var exists = false;
  var lookupDenied = false;
  var insertionDenied = false;
  var concurrentInsert = false;
  setUp(() {
    requests = [];
    exists = lookupDenied = insertionDenied = concurrentInsert = false;
    client = SupabaseClient(
      'https://fixture.invalid',
      'fixture-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final isRead = request.method == 'GET';
        final denied = isRead ? lookupDenied : insertionDenied;
        final rows = isRead
            ? (exists
                  ? [
                      {'id': userId},
                    ]
                  : [])
            : (concurrentInsert
                  ? []
                  : [
                      {'id': userId},
                    ]);
        return http.Response(
          jsonEncode(denied ? {'code': '42501', 'message': 'denied'} : rows),
          denied ? 403 : 200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDown(() => client.dispose());

  test('an existing profile is never written during sign-in', () async {
    exists = true;
    expect(await AuthProfileInitializer(client).ensureProfile(user), isFalse);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
  });
  test(
    'a missing profile is initialized with conflict-ignore semantics',
    () async {
      expect(await AuthProfileInitializer(client).ensureProfile(user), isTrue);
      expect(
        requests.last.headers['prefer'],
        contains('resolution=ignore-duplicates'),
      );
      expect(requests.last.url.queryParameters['on_conflict'], 'id');
      expect(jsonDecode(requests.last.body)['full_name'], 'Initial name');
      expect(jsonDecode(requests.last.body)['role'], 'user');
    },
  );
  test(
    'a concurrent profile creation is not overwritten or called new',
    () async {
      concurrentInsert = true;
      expect(await AuthProfileInitializer(client).ensureProfile(user), isFalse);
      expect(
        requests.last.headers['prefer'],
        contains('resolution=ignore-duplicates'),
      );
    },
  );
  test('a failed lookup cannot be treated as a missing profile', () async {
    lookupDenied = true;
    await expectLater(
      AuthProfileInitializer(client).ensureProfile(user),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });
  test(
    'a failed initialization is not successful authentication completion',
    () async {
      insertionDenied = true;
      await expectLater(
        AuthProfileInitializer(client).ensureProfile(user),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
