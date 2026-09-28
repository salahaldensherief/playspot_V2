import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/notifications/presentation/widgets/qr_location_dialog.dart';

void main() {
  group('QrLocationDialog URL Validation Unit Tests', () {
    test('isValidLocationUrl returns false for empty or whitespace strings', () {
      expect(QrLocationDialog.isValidLocationUrl(''), isFalse);
      expect(QrLocationDialog.isValidLocationUrl('   '), isFalse);
    });

    test('isValidLocationUrl returns false for malformed URLs without scheme or host', () {
      expect(QrLocationDialog.isValidLocationUrl('invalid_url'), isFalse);
      expect(QrLocationDialog.isValidLocationUrl('google.com/maps'), isFalse); // missing http/https scheme
    });

    test('isValidLocationUrl returns false for non-http/https schemes', () {
      expect(QrLocationDialog.isValidLocationUrl('ftp://maps.google.com'), isFalse);
      expect(QrLocationDialog.isValidLocationUrl('javascript:alert(1)'), isFalse);
    });

    test('isValidLocationUrl returns true for valid Google Maps and Apple Maps URLs', () {
      expect(
        QrLocationDialog.isValidLocationUrl('https://maps.google.com/?q=30.0,31.0'),
        isTrue,
      );
      expect(
        QrLocationDialog.isValidLocationUrl('https://maps.app.goo.gl/abc123xyz'),
        isTrue,
      );
      expect(
        QrLocationDialog.isValidLocationUrl('http://maps.apple.com/?address=Cairo'),
        isTrue,
      );
    });
  });
}
