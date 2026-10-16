import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/features/auth/data/strategies/email_auth_strategy.dart';

void main() {
  for (final field in ['full_name', 'avatar_url']) {
    test('existing edited profile retains $field after email login', () async {
      const userId = '00000000-0000-0000-0000-000000000001';
      final profile = <String, dynamic>{
        'id': userId,
        'full_name': 'Customer edited display name',
        'avatar_url': 'https://fixture.invalid/customer-edited-avatar.png',
      };
      final previous = profile[field];
      final token =
          '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
          '${base64Url.encode(utf8.encode(jsonEncode({'sub': userId, 'role': 'authenticated', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture';
      final client = SupabaseClient(
        'https://fixture.invalid',
        'synthetic-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            return http.Response(
              jsonEncode({
                'access_token': token,
                'refresh_token': 'synthetic-refresh-token',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': userId,
                  'aud': 'authenticated',
                  'email': 'customer@example.invalid',
                  'created_at': '2026-10-01T00:00:00Z',
                  'app_metadata': {'provider': 'email'},
                  'user_metadata': {},
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          if (request.url.path == '/rest/v1/profiles') {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode([profile]),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            profile.addAll(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response('', 201, request: request);
          }
          throw StateError(
            'Unexpected mock request: ${request.method} ${request.url.path}',
          );
        }),
      );
      addTearDown(client.dispose);
      final user = await EmailAuthStrategy(client).authenticate({
        'email': 'customer@example.invalid',
        'password': 'synthetic-test-only',
      });
      expect(user.id, userId);
      expect(user.isNewUser, isFalse);
      expect(
        profile[field],
        previous,
        reason: 'Signing in must preserve customer-edited profile fields',
      );
    });
  }
}
