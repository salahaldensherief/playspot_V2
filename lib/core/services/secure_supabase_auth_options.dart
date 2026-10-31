import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_auth_local_storage.dart';
import 'secure_auth_pkce_storage.dart';
import 'secure_auth_value_store.dart';
import 'play_spot_secure_storage.dart';

class SecureSupabaseAuthOptions {
  const SecureSupabaseAuthOptions._();

  static FlutterAuthClientOptions forUrl(
    String url, {
    FlutterSecureStorage storage = PlaySpotSecureStorage.instance,
  }) {
    final uri = Uri.parse(url);
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError('auth.invalid_storage_scope');
    }
    final endpoint = uri.replace(
      path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
    );
    final scope = base64Url.encode(utf8.encode(endpoint.toString()));
    final values = SecureAuthValueStore(
      storage: storage,
      namespace: 'playspot-auth-v1:$scope',
    );
    return FlutterAuthClientOptions(
      localStorage: SecureAuthLocalStorage(
        values: values,
        legacy: _legacyStorage(endpoint),
      ),
      pkceAsyncStorage: SecureAuthPkceStorage(values: values),
    );
  }

  static LocalStorage _legacyStorage(Uri endpoint) {
    final labels = endpoint.host.split('.');
    final standardProject =
        endpoint.scheme == 'https' &&
        endpoint.port == 443 &&
        endpoint.path.isEmpty &&
        labels.length == 3 &&
        labels[1] == 'supabase' &&
        labels[2] == 'co';
    if (!standardProject) return const EmptyLocalStorage();
    return SharedPreferencesLocalStorage(
      persistSessionKey: 'sb-${labels.first}-auth-token',
    );
  }
}
