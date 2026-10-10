import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/home/domain/repositories/home_repository.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/domain/repositories/lounge_details_repository.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:playspot/features/my_bookings/domain/usecases/prepare_quick_rebook_usecase.dart';

class _Home extends Mock implements HomeRepository {}

class _Details extends Mock implements LoungeDetailsRepository {}

void main() {
  late _Home home;
  late _Details details;
  late PrepareQuickRebookUseCase prepare;
  final booking = BookingModel.fromJson({
    'id': 'booking',
    'lounge_id': 'lounge',
    'room_id': 'room',
    'date': '2030-01-01',
    'start_time': '12:00',
    'end_time': '13:00',
    'status': 'completed',
    'total_price': 100,
  });
  const lounge = LoungeModel(
    id: 'lounge',
    name: 'Synthetic',
    location: '',
    imageUrl: '',
    rating: 0,
    distance: 0,
    pricePerHour: 100,
    isOpen: true,
    openingTime: '00:00',
    closingTime: '23:59',
  );
  const room = RoomModel(
    id: 'room',
    loungeId: 'lounge',
    nameEn: 'Synthetic',
    nameAr: '',
    maxCapacity: 4,
    isAvailable: true,
    images: [],
    featuresAr: [],
    featuresEn: [],
    controllersCount: 2,
    hourlyRateSingle: 100,
    hourlyRateMulti: 150,
    activityNames: [],
  );
  const failure = NetworkFailure('synthetic-network-failure');
  setUp(() {
    home = _Home();
    details = _Details();
    prepare = PrepareQuickRebookUseCase(home, details);
    when(
      () => home.getLoungeById('lounge'),
    ).thenAnswer((_) async => const Right(lounge));
    when(
      () => details.getRoomById('room', forceRefresh: true),
    ).thenAnswer((_) async => const Right(room));
    when(
      () => details.getExtras('lounge', forceRefresh: true),
    ).thenAnswer((_) async => const Right([]));
  });
  test(
    'lounge transport failure is preserved and stops room requests',
    () async {
      when(
        () => home.getLoungeById('lounge'),
      ).thenAnswer((_) async => const Left(failure));
      expect(
        (await prepare(
          booking,
        )).swap().getOrElse(() => throw StateError('Expected failure')),
        same(failure),
      );
      verifyNever(() => details.getRoomById('room', forceRefresh: true));
    },
  );
  test(
    'room authorization failure is preserved and stops addon requests',
    () async {
      const denied = AuthFailure('synthetic-denial');
      when(
        () => details.getRoomById('room', forceRefresh: true),
      ).thenAnswer((_) async => const Left(denied));
      expect(
        (await prepare(
          booking,
        )).swap().getOrElse(() => throw StateError('Expected failure')),
        same(denied),
      );
      verifyNever(() => details.getExtras('lounge', forceRefresh: true));
    },
  );
  test(
    'addon failure cannot produce a ready setup with an empty menu',
    () async {
      when(
        () => details.getExtras('lounge', forceRefresh: true),
      ).thenAnswer((_) async => const Left(failure));
      expect(
        (await prepare(
          booking,
        )).swap().getOrElse(() => throw StateError('Expected failure')),
        same(failure),
      );
    },
  );
  test(
    'confirmed missing lounge keeps the unavailable business result',
    () async {
      when(
        () => home.getLoungeById('lounge'),
      ).thenAnswer((_) async => const Right(null));
      expect(
        (await prepare(
          booking,
        )).swap().getOrElse(() => throw StateError('Expected failure')).message,
        'quickRebookLoungeUnavailable',
      );
    },
  );
  test('confirmed empty menu is a successful setup', () async {
    expect((await prepare(booking)).isRight(), isTrue);
  });
}
