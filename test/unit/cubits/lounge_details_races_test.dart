import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/domain/entities/lounge_operating_status.dart';
import 'package:playspot/features/lounge_details/domain/repositories/lounge_details_repository.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'package:playspot/features/tournaments/domain/usecases/get_tournaments_usecase.dart';

import '../../support/mock_home_repository.dart';

class _Details extends Mock implements LoungeDetailsRepository {}

class _Bookings extends Mock implements BookingRepository {}

class _Tournaments extends Mock implements GetTournamentsUseCase {}

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2026)));
  late _Details details;
  late _Bookings bookings;
  late LoungeDetailsCubit cubit;
  setUp(() {
    details = _Details();
    bookings = _Bookings();
    final tournaments = _Tournaments();
    when(() => tournaments(loungeId: any(named: 'loungeId')))
        .thenAnswer((_) async => const Right([]));
    for (final id in ['a', 'b']) {
      when(() => details.getRoomsByLoungeId(id, forceRefresh: false))
          .thenAnswer(
            (_) async => Right([
              RoomModel.fromJson({'id': '$id-room', 'lounge_id': id}),
            ]),
          );
      when(() => details.getExtras(id))
          .thenAnswer((_) async => const Right([]));
      when(() => details.getLoungeCategories(id))
          .thenAnswer((_) async => const Right([]));
      when(() => details.getLoungeReviews(id))
          .thenAnswer((_) async => const Right([]));
      when(() => details.getLoungeOperatingStatus(id)).thenAnswer(
        (_) async => const Right(
          LoungeOperatingStatus(status: 'open', canBookOnline: true),
        ),
      );
      when(() => bookings.getRoomBookingsForDate(id, any()))
          .thenAnswer((_) async => const Right([]));
    }
    cubit = LoungeDetailsCubit(
      details,
      MockHomeRepository(),
      bookings,
      tournaments,
    );
    addTearDown(cubit.close);
  });
  Future<void> ready(String id) async {
    cubit.init(LoungeModel.fromJson({'id': id}));
    await cubit.stream.firstWhere(
      (s) => s.status == LoungeDetailsStatus.success && s.lounge?.id == id,
    );
  }

  test('late room/status response cannot overwrite another lounge', () async {
    final pending = Completer<Either<Failure, List<RoomModel>>>();
    when(() => details.getRoomsByLoungeId('a', forceRefresh: false))
        .thenAnswer((_) => pending.future);
    cubit.init(LoungeModel.fromJson({'id': 'a'}));
    await ready('b');
    pending.complete(
      Right([
        RoomModel.fromJson({'id': 'a-room'}),
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.lounge?.id, 'b');
    expect(cubit.state.rooms.single.id, 'b-room');
  });
  test('late booking response cannot republish the previous lounge', () async {
    final pending = Completer<Either<Failure, List<Map<String, dynamic>>>>();
    when(() => bookings.getRoomBookingsForDate('a', any()))
        .thenAnswer((_) => pending.future);
    cubit.init(LoungeModel.fromJson({'id': 'a'}));
    await Future<void>.delayed(Duration.zero);
    await ready('b');
    pending.complete(const Right([]));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.lounge?.id, 'b');
    expect(cubit.state.rooms.single.id, 'b-room');
  });
  test(
    'failed operating status keeps browsing but denies online booking',
    () async {
      when(() => details.getLoungeOperatingStatus('a'))
          .thenAnswer((_) async => const Left(ServerFailure('PGRST202')));
      await ready('a');
      expect(cubit.state.rooms, isNotEmpty);
      expect(cubit.state.operatingStatus?.status, 'unavailable');
      expect(cubit.state.operatingStatus?.canBookOnline, isFalse);
    },
  );
  test(
    'booking-date failure retains fresh operating status and venue phone',
    () async {
      when(() => details.getLoungeOperatingStatus('a')).thenAnswer(
        (_) async => const Right(
          LoungeOperatingStatus(
            status: 'technical_issue',
            canBookOnline: false,
            contactPhone: '01012345678',
          ),
        ),
      );
      when(() => bookings.getRoomBookingsForDate('a', any()))
          .thenAnswer((_) async => const Left(ServerFailure('offline')));
      await ready('a');
      expect(cubit.state.operatingStatus?.status, 'technical_issue');
      expect(cubit.state.operatingStatus?.contactPhone, '01012345678');
      expect(cubit.state.operatingStatus?.canBookOnline, isFalse);
      expect(cubit.state.rooms, isNotEmpty);
    },
  );
}
