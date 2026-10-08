import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/room_card_presentation.dart';
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
    operatingStatus: const LoungeOperatingStatus(
      status: 'open',
      canBookOnline: true,
    ),
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
      ]) {
        expect(LoungeBookingSelection(invalid, lounge).params, isNull);
      }
    },
  );
  test('current room occupancy does not block a later booking', () {
    final occupied = state.copyWith(
      rooms: [
        RoomModel.fromJson({
          'id': 'r',
          'status': 'occupied',
          'is_available': false,
        }),
      ],
    );

    expect(LoungeBookingSelection(occupied, lounge).isEnabled, isTrue);
    expect(LoungeBookingSelection(occupied, lounge).params, isNotNull);
  });

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
  test('missing status never falls back to a cached open lounge', () {
    expect(lounge.isOpen, isTrue);
    final unknown = state.copyWith(clearOperatingStatus: true);
    expect(LoungeBookingSelection(unknown, lounge).params, isNull);
  });
  test('invalid or contradictory server statuses are rejected', () {
    for (final value in [
      <String, dynamic>{},
      {'status': 'new_unknown', 'can_book_online': true},
      {'status': 'closed', 'can_book_online': true},
      {'status': 'open', 'can_book_online': 'true'},
      {
        'status': 'technical_issue',
        'can_book_online': false,
        'contact_phone': 123,
      },
    ]) {
      expect(
        () => LoungeOperatingStatus.fromJson(value),
        throwsFormatException,
      );
    }
  });
  test('fresh operating status overrides a stale cached lounge flag', () {
    final cachedClosed = LoungeModel.fromJson({'id': 'l', 'is_open': false});
    final freshOpen = state.copyWith(lounge: cachedClosed);
    expect(RoomCardPresentation.fromState(room, freshOpen).isAvailable, isTrue);
    expect(LoungeBookingSelection(freshOpen, cachedClosed).isEnabled, isTrue);
    final freshClosed = state.copyWith(
      operatingStatus: const LoungeOperatingStatus(status: 'closed', canBookOnline: false),
    );
    expect(RoomCardPresentation.fromState(room, freshClosed).isAvailable, isFalse);
    expect(LoungeBookingSelection(freshClosed, lounge).params, isNull);
  });

  test('contact phone survives parsing, caching and distance updates', () {
    final contact = LoungeModel.fromJson({'id': 'l', 'contact_phone': ' 01012345678 '});
    expect(contact.contactPhone, '01012345678');
    expect(LoungeModel.fromJson(contact.toJson()).contactPhone, '01012345678');
    expect(contact.withDistanceEstimate(2).contactPhone, '01012345678');
    expect(LoungeModel.fromJson({'id': 'l'}).contactPhone, isNull);
  });

}
