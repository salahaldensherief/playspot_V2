import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_auth_value_store.dart';

class SecureAuthPkceStorage extends GotrueAsyncStorage {
  final SecureAuthValueStore values;
  const SecureAuthPkceStorage({required this.values});

  @override
  Future<String?> getItem({required String key}) => values.read(
    'pkce:$key',
    legacyRead: () async => null,
    legacyRemove: () async {},
  );

  @override
  Future<void> setItem({required String key, required String value}) =>
      values.write('pkce:$key', value, legacyRemove: () async {});

  @override
  Future<void> removeItem({required String key}) =>
      values.remove('pkce:$key', legacyRemove: () async {});
}
