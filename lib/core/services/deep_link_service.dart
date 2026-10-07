import '../../art_core/utils/app_logger.dart';
import '../cache/preference_manager.dart';

class DeepLinkService {
  final PreferenceManager _preferenceManager;
  DeepLinkService(this._preferenceManager);

  void handleIncomingUri(Uri uri) {
    AppLogger.debug('[DeepLinkService] Handling URI: $uri');
    final queryParams = uri.queryParameters;
    final code = queryParams['code'] ??
        queryParams['ref'] ??
        queryParams['referral'] ??
        queryParams['p_referral_code'];

    if (code != null && code.trim().isNotEmpty) {
      final cleanCode = code.trim().toUpperCase();
      AppLogger.debug('[DeepLinkService] Extracted referral code from URI: $cleanCode');
      _preferenceManager.savePendingReferralCode(cleanCode);
    }
  }

}
