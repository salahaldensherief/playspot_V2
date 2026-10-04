import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/domain/entities/lounge_operating_status.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_booking_selection.dart';

void main() {
  final lounge = LoungeModel.fromJson({'id': 'l'});
  final room = RoomModel.fromJson({'id': 'r', 'is_available': true});
  final state = LoungeDetailsState(
    status: LoungeDetailsStatus.success,
    lounge: lounge,
    rooms: [room],
    selectedRoomIds: {'r'},
  );
  test('booking reads the current selected date and per-room settings', () {
    final date = DateTime(2026, 11, 12);
    final current = state.copyWith(
      selectedDate: date,
      roomPlayModes: {'r': 'single'},
      roomExtraControllers: {'r': 2},
    );
    final params = LoungeBookingSelection(current, lounge).params;
    expect(params?.selectedDate, date);
    expect(params?.playMode, 'single');
    expect(params?.extraControllers, 2);
    expect(params?.roomPlayModes, {'r': 'single'});
    expect(params?.roomExtraControllers, {'r': 2});
  });
  test(
    'loading, unavailable, stale or booked room selections cannot proceed',
    () {
      for (final invalid in [
        state.copyWith(isDateLoading: true),
        state.copyWith(status: LoungeDetailsStatus.error),
        state.copyWith(rooms: []),
        state.copyWith(bookedRoomIds: ['r']),
        state.copyWith(
          rooms: [
            RoomModel.fromJson({'id': 'r', 'status': 'occupied'}),
          ],
        ),
      ]) {
        expect(LoungeBookingSelection(invalid, lounge).params, isNull);
      }
    },
  );
  test('technical issue or non-bookable operating status disables booking', () {
    final techIssue = state.copyWith(
      operatingStatus: const LoungeOperatingStatus(
        status: 'technical_issue',
        canBookOnline: false,
        contactPhone: '01012345678',
      ),
    );
    expect(LoungeBookingSelection(techIssue, lounge).isEnabled, isFalse);
    expect(LoungeBookingSelection(techIssue, lounge).params, isNull);

    final openStatus = state.copyWith(
      operatingStatus: const LoungeOperatingStatus(
        status: 'open',
        canBookOnline: true,
      ),
    );
    expect(LoungeBookingSelection(openStatus, lounge).isEnabled, isTrue);
    expect(LoungeBookingSelection(openStatus, lounge).params, isNotNull);
  });
}
