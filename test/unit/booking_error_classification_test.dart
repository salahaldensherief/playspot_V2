import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/core/utils/booking_error_formatter.dart';

void main() {
  test('not authorized is a permission denial, not an expired session', () {
    expect(getBookingErrorMessage('not authorized', true), contains('permission'));
    expect(getBookingErrorMessage('42501', false), contains('صلاحية'));
  });
  test('expired JWT asks for login while ambiguous unauthorized does not assert expiry', () {
    expect(getBookingErrorMessage('JWT expired', true), contains('Session expired'));
    expect(getBookingErrorMessage('Unauthorized', true), isNot(contains('Session expired')));
  });
}
