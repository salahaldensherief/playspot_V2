import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/config/local_acceptance.dart';

void main() {
  String jwt(String role, String issuer) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role, 'iss': issuer})))}.signature';
  test(
    'local mode accepts public configuration and rejects privileged keys',
    () {
      for (final key in [
        jwt('anon', 'supabase-demo'),
        'sb_publishable_synthetic',
      ]) {
        expect(
          () => validateLocalAcceptancePublicKey(enabled: true, key: key),
          returnsNormally,
        );
      }
      for (final key in [
        '',
        'sb_secret_synthetic',
        jwt('service_role', 'supabase-demo'),
        jwt('anon', 'hosted'),
      ]) {
        expect(
          () => validateLocalAcceptancePublicKey(enabled: true, key: key),
          throwsStateError,
        );
      }
      expect(
        () => validateLocalAcceptancePublicKey(enabled: false, key: ''),
        returnsNormally,
      );
    },
  );
}
