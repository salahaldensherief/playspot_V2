import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/active_session/domain/entities/active_session.dart';

void main() {
  ActiveSession session(String extensionStatus) => ActiveSession(
    bookingId: 'booking-1',
    loungeId: 'lounge-1',
    loungeName: 'Lounge',
    roomName: 'PS5',
    deviceName: 'PS5',
    startTime: DateTime.utc(2026, 10, 16, 14),
    endTime: DateTime.utc(2026, 10, 16, 15),
    basePrice: 100,
    status: 'in_progress',
    extensionStatus: extensionStatus,
    requestedExtensionMinutes: 30,
  );

  test('only pending extension requests display the pending state', () {
    expect(session('pending').isExtensionPending, isTrue);
    expect(session('rejected').isExtensionPending, isFalse);
    expect(session('approved').isExtensionPending, isFalse);
    expect(session('expired').isExtensionPending, isFalse);
  });

  test('rejected request may retain minutes but must not be pending', () {
    final rejected = session('rejected');
    expect(rejected.requestedExtensionMinutes, 30);
    expect(rejected.isExtensionPending, isFalse);
    expect(rejected.isExtensionRejected, isTrue);
  });
}
