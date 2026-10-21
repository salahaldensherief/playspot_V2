import '../cache/preference_manager.dart';

class DeepLinkService {
  final PreferenceManager _preferenceManager;
  DeepLinkService(this._preferenceManager);

  void handleIncomingUri(Uri uri) {
    // Supabase OAuth/PKCE callbacks may contain an authorization "code".
    // That credential must never be saved or logged as a referral code.
    if (uri.scheme == 'com.playspot.client' && uri.host == 'login-callback') {
      return;
    }

    final queryParams = uri.queryParameters;
    // Prefer explicit referral parameters to the legacy generic "code".
    final code =
        queryParams['ref'] ??
        queryParams['referral'] ??
        queryParams['p_referral_code'] ??
        queryParams['code'];

    if (code == null || code.trim().isEmpty) return;
    // Do not log the incoming URL or referral value: URLs may contain tokens.
    _preferenceManager.savePendingReferralCode(code.trim().toUpperCase());
  }
}
