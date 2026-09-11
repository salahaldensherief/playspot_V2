import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cache/preference_manager.dart';

class DeepLinkService {
  final PreferenceManager _preferenceManager;
  final SupabaseClient _supabase;
  StreamSubscription? _authSubscription;

  DeepLinkService(this._preferenceManager, this._supabase);

  void initialize() {
    // Listen to Supabase auth events or link callbacks which receive incoming URIs
    try {
      _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
        // If an OAuth or email confirmation redirect carries query parameters in session/URL
        // we can handle initial link checking or session events.
      });
    } catch (e) {
      debugPrint('[DeepLinkService] Initialization error: $e');
    }
  }

  void handleIncomingUri(Uri uri) {
    debugPrint('[DeepLinkService] Handling URI: $uri');
    final queryParams = uri.queryParameters;
    final code = queryParams['code'] ??
        queryParams['ref'] ??
        queryParams['referral'] ??
        queryParams['p_referral_code'];

    if (code != null && code.trim().isNotEmpty) {
      final cleanCode = code.trim().toUpperCase();
      debugPrint('[DeepLinkService] Extracted referral code from URI: $cleanCode');
      _preferenceManager.savePendingReferralCode(cleanCode);
    }
  }

  void dispose() {
    _authSubscription?.cancel();
  }
}
