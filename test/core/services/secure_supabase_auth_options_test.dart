import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/core/services/secure_supabase_auth_options.dart';
import 'package:playspot/core/services/secure_auth_local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'offline-journal-key': 'retain',
    });
    SharedPreferences.setMockInitialValues({
      'sb-first-auth-token': 'legacy-first',
      'sb-second-auth-token': 'legacy-second',
      'sb-auth-token-code-verifier': 'unscoped-legacy-verifier',
      'theme': 'dark',
    });
  });

  test('production storage cannot silently erase keys on Android errors', () {
    final sessions =
        SecureSupabaseAuthOptions.forUrl(
              'https://first.supabase.co',
            ).localStorage
            as SecureAuthLocalStorage;
    final android = sessions.values.storage.aOptions.toMap();
    expect(android['resetOnError'], 'false');
    expect(android['migrateWithBackup'], 'true');
    expect(android['migrateOnAlgorithmChange'], 'true');
  });

  test('SDK options migrate only the selected project session', () async {
    final options = SecureSupabaseAuthOptions.forUrl(
      'https://first.supabase.co',
    );
    final sessions = options.localStorage;
    expect(sessions, isNotNull);
    await sessions?.initialize();
    expect(await sessions?.hasAccessToken(), isTrue);
    expect(await sessions?.accessToken(), 'legacy-first');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('sb-first-auth-token'), isFalse);
    expect(prefs.getString('sb-second-auth-token'), 'legacy-second');
    expect(prefs.getString('theme'), 'dark');
    expect(await storage.read(key: 'offline-journal-key'), 'retain');
    await sessions?.persistSession('fresh-first');
    expect(await sessions?.accessToken(), 'fresh-first');
    expect(prefs.containsKey('sb-first-auth-token'), isFalse);
    await sessions?.removePersistedSession();
    expect(await sessions?.hasAccessToken(), isFalse);
    expect(await storage.read(key: 'offline-journal-key'), 'retain');
  });

  test(
    'session scope separates endpoint scheme, port, path and project',
    () async {
      final urls = [
        'https://first.supabase.co',
        'https://second.supabase.co',
        'http://localhost:54321',
        'http://localhost:54322',
        'https://localhost:54321',
        'http://localhost:54321/tenant',
      ];
      final stores = urls
          .map((url) => SecureSupabaseAuthOptions.forUrl(url).localStorage)
          .toList();
      for (var i = 0; i < stores.length; i++) {
        await stores[i]?.persistSession('session-$i');
      }
      for (var i = 0; i < stores.length; i++) {
        expect(await stores[i]?.accessToken(), 'session-$i');
      }
      final trailing = SecureSupabaseAuthOptions.forUrl(
        '${urls.first}/',
      ).localStorage;
      expect(await trailing?.accessToken(), 'session-0');
    },
  );

  test(
    'PKCE is secure and scoped; unscoped legacy verifier is not imported',
    () async {
      final first = SecureSupabaseAuthOptions.forUrl(
        'https://first.supabase.co',
      );
      final second = SecureSupabaseAuthOptions.forUrl(
        'https://second.supabase.co',
      );
      const key = 'sb-auth-token-code-verifier';
      expect(await first.pkceAsyncStorage?.getItem(key: key), isNull);
      await first.pkceAsyncStorage?.setItem(key: key, value: 'first-verifier');
      await second.pkceAsyncStorage?.setItem(
        key: key,
        value: 'second-verifier',
      );
      expect(await first.pkceAsyncStorage?.getItem(key: key), 'first-verifier');
      expect(
        await second.pkceAsyncStorage?.getItem(key: key),
        'second-verifier',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), 'unscoped-legacy-verifier');
      await first.pkceAsyncStorage?.removeItem(key: key);
      expect(await first.pkceAsyncStorage?.getItem(key: key), isNull);
      expect(
        await second.pkceAsyncStorage?.getItem(key: key),
        'second-verifier',
      );
    },
  );

  for (final url in [
    'https://first.example.com',
    'https://first.supabase.co:8443',
    'https://first.supabase.co/tenant',
    'http://first.supabase.co',
  ]) {
    test('ambiguous legacy scope is retained without import: $url', () async {
      final sessions = SecureSupabaseAuthOptions.forUrl(url).localStorage;
      expect(await sessions?.accessToken(), isNull);
      await sessions?.removePersistedSession();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sb-first-auth-token'), 'legacy-first');
      expect(await storage.readAll(), {'offline-journal-key': 'retain'});
    });
  }

  for (final url in [
    'file:///tmp',
    'https://user:secret@example.com',
    'https://example.com?token=value',
    'https://example.com#token',
    'invalid',
  ]) {
    test(
      'invalid endpoint is rejected without a storage write: $url',
      () async {
        expect(() => SecureSupabaseAuthOptions.forUrl(url), throwsStateError);
        expect(await storage.readAll(), {'offline-journal-key': 'retain'});
      },
    );
  }
}
