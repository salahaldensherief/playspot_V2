import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/utils/app_validators.dart';

void main() {
  for (final suffix in ['travel', 'museum', 'technology']) {
    test('valid email syntax permits the .$suffix top-level domain', () {
      expect(
        AppValidators.validateEmail('customer@example.$suffix'),
        isNull,
        reason: 'A valid email domain is not limited to four final characters',
      );
    });
  }
  for (final email in [
    'person+tag@sub.example.com',
    'person@example.xn--p1ai',
  ]) {
    test('valid email syntax accepts $email', () {
      expect(AppValidators.validateEmail(email), isNull);
    });
  }
  for (final email in [
    'missing-at.example.com',
    'person@-example.com',
    'person@example-.com',
    'person@example..com',
    'person@example.c',
    'person@example.com trailing',
  ]) {
    test('invalid email syntax rejects $email', () {
      expect(AppValidators.validateEmail(email), isNotNull);
    });
  }
}
