import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/services/deep_link_service.dart';

class _MockPreferenceManager extends Mock implements PreferenceManager {}

void main() {
  late _MockPreferenceManager preferences;
  late DeepLinkService service;

  setUp(() {
    preferences = _MockPreferenceManager();
    service = DeepLinkService(preferences);
    when(
      () => preferences.savePendingReferralCode(any()),
    ).thenAnswer((_) async {});
  });

  test('OAuth login callback code is never stored as a referral', () {
    service.handleIncomingUri(
      Uri.parse(
        'com.playspot.client://login-callback?code=private-pkce-code'
        '&state=private-state',
      ),
    );

    verifyNever(() => preferences.savePendingReferralCode(any()));
  });

  test('explicit referral wins over a generic code parameter', () {
    service.handleIncomingUri(
      Uri.parse('https://example.invalid/venue?code=other&ref=friend42'),
    );

    verify(() => preferences.savePendingReferralCode('FRIEND42')).called(1);
  });

  test('legacy code-only referral links remain supported', () {
    service.handleIncomingUri(
      Uri.parse('https://example.invalid/lounge?code=launch20'),
    );

    verify(() => preferences.savePendingReferralCode('LAUNCH20')).called(1);
  });

  test('empty referral link leaves existing attribution untouched', () {
    service.handleIncomingUri(Uri.parse('https://example.invalid/lounge'));

    verifyNever(() => preferences.savePendingReferralCode(any()));
  });
}
