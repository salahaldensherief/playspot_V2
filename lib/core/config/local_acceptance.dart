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
      uri.port != 56621 ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty) {
    throw StateError('Local acceptance requires http://127.0.0.1:56621.');
  }
}
