import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/config/local_acceptance.dart';

void main() {
  test('ordinary builds keep their explicit environment contract', () {
    expect(
      () => validateLocalAcceptanceTarget(enabled: false, url: ''),
      returnsNormally,
    );
  });
  test('local acceptance requires the exact isolated endpoint', () {
    expect(
      () => validateLocalAcceptanceTarget(
        enabled: true,
        url: 'http://127.0.0.1:56621',
      ),
      returnsNormally,
    );
    for (final url in [
      '',
      'https://hosted.supabase.co',
      'http://localhost:56621',
      'http://127.0.0.1:54321',
      'http://127.0.0.1:56621/other',
      'http://127.0.0.1:56621/?redirect=hosted',
      'http://user@127.0.0.1:56621',
      'http://127.0.0.1:56621/#hosted',
    ]) {
      expect(
        () => validateLocalAcceptanceTarget(enabled: true, url: url),
        throwsStateError,
        reason: url,
      );
    }
  });
}
