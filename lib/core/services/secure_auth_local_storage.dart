import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_auth_value_store.dart';

class SecureAuthLocalStorage extends LocalStorage {
  final SecureAuthValueStore values;
  final LocalStorage legacy;
  Future<void>? _initialization;
  SecureAuthLocalStorage({required this.values, required this.legacy});

  @override
  Future<void> initialize() => _initialization ??= legacy.initialize();

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<String?> accessToken() async {
    await initialize();
    return values.read(
      'session',
      legacyRead: legacy.accessToken,
      legacyRemove: legacy.removePersistedSession,
    );
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await initialize();
    await values.write(
      'session',
      persistSessionString,
      legacyRemove: legacy.removePersistedSession,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    await initialize();
    await values.remove('session', legacyRemove: legacy.removePersistedSession);
  }
}
