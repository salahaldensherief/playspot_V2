import 'dart:convert';

/// Opt-in isolation for synthetic acceptance. Never chooses a backend or key.
const localAcceptance = bool.fromEnvironment('PLAYSPOT_LOCAL_ACCEPTANCE');

void validateLocalAcceptanceTarget({
  required bool enabled,
  required String url,
}) {
  if (!enabled) return;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'http' ||
      uri.host != '127.0.0.1' ||
      !const {56621, 56821}.contains(uri.port) ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty) {
    throw StateError(
      'Local development requires the explicit loopback API on port 56621 or 56821.',
    );
  }
}

/// Offline format/provenance guard, not signature or server-key verification.
void validateLocalAcceptancePublicKey({
  required bool enabled,
  required String key,
}) {
  if (!enabled) return;
  if (RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(key)) return;
  try {
    final parts = key.split('.');
    if (parts.length == 3) {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is Map &&
          claims['role'] == 'anon' &&
          claims['iss'] == 'supabase-demo' &&
          (claims['ref'] == null ||
              claims['ref'] == 'playspot-acceptance-20261030' ||
              claims['ref'] == 'playspot-dev-clean-20261031')) {
        return;
      }
    }
  } catch (_) {
    /* Invalid public configuration fails closed below. */
  }
  throw StateError(
    'Local acceptance requires a local public anon/publishable key.',
  );
}
