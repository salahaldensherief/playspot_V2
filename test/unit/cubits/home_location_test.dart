import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/home/data/models/home_params.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/home/presentation/home_cubit.dart';
import 'package:playspot/features/home/presentation/home_location_tracker.dart';
import 'package:playspot/features/home/presentation/home_state.dart';
import 'package:playspot/features/tournaments/domain/usecases/get_tournaments_usecase.dart';
import 'package:playspot/features/tournaments/domain/usecases/get_home_tournament_usecase.dart';
import 'package:playspot/features/tournaments/domain/usecases/get_my_active_tournament_usecase.dart';
import '../../support/mock_home_repository.dart';
import '../../support/mock_location_service.dart';
import '../../support/mock_preference_manager.dart';
import '../../support/mock_discover_lounges_usecase.dart';
import '../../support/mock_tournaments_repository.dart';

Position position(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.now(),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
Future<void> flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockHomeRepository repo;
  late MockLocationService location;
  late MockPreferenceManager pref;
  late MockDiscoverLoungesUseCase discover;
  late MockTournamentsRepository tournaments;
  late StreamController<Position> positions;
  late HomeCubit cubit;
  late String lat;
  late String lng;
  final lounge = LoungeModel.fromJson({'id': 'l', 'name': 'Fixture'});
  setUpAll(() => registerFallbackValue(const GetLoungesParams()));
  setUp(() {
    repo = MockHomeRepository();
    location = MockLocationService();
    pref = MockPreferenceManager();
    discover = MockDiscoverLoungesUseCase();
    tournaments = MockTournamentsRepository();
    positions = StreamController.broadcast();
    lat = '';
    lng = '';
    when(() => pref.latitude()).thenAnswer((_) => lat);
    when(() => pref.longitude()).thenAnswer((_) => lng);
    when(() => pref.userId()).thenReturn('');
    when(() => pref.getValue(any())).thenReturn('');
    when(() => pref.saveValue(any(), any())).thenAnswer((_) async {});
    when(() => pref.saveLatitude(any())).thenAnswer((call) async {
      lat = '${call.positionalArguments.first}';
    });
    when(() => pref.saveLongitude(any())).thenAnswer((call) async {
      lng = '${call.positionalArguments.first}';
    });
    when(() => location.getCurrentLocation()).thenAnswer((_) async => null);
    when(
      () => location.getAddressFromLatLng(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => repo.getAvailableCities(),
    ).thenAnswer((_) async => const Right([]));
    when(() => repo.getCategories()).thenAnswer((_) async => const Right([]));
    when(
      () => repo.getPromotions(loungeId: null),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => tournaments.getHomeTournament(),
    ).thenAnswer((_) async => const Right(null));
    when(() => discover(any())).thenAnswer((_) async => Right([lounge]));
    cubit = HomeCubit(
      repo,
      location,
      GetTournamentsUseCase(tournaments),
      GetHomeTournamentUseCase(tournaments),
      GetMyActiveTournamentUseCase(tournaments),
      preferenceManager: pref,
      discover: discover,
      positions: () => positions.stream,
    );
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
    await positions.close();
  });

  test(
    'denied GPS at bootstrap still loads lounges with unknown distance',
    () async {
      await cubit.init();
      await flush();
      expect(cubit.state.status, HomeStatus.success);
      expect(cubit.state.isLoungesLoading, false);
      expect(cubit.state.nearestLounges, [lounge]);
      final params =
          verify(() => discover(captureAny())).captured.single
              as GetLoungesParams;
      expect(params.lat, isNull);
      expect(params.lng, isNull);
      verifyNever(() => pref.saveLatitude(any()));
    },
  );
  test(
    'invalid or partial saved location sends neither half of the pair',
    () async {
      lat = '91';
      lng = '31';
      await cubit.getHomeData();
      final params =
          verify(() => discover(captureAny())).captured.single
              as GetLoungesParams;
      expect(params.lat, isNull);
      expect(params.lng, isNull);
    },
  );
  test(
    'failure ends loading without silently clearing cached lounges',
    () async {
      await cubit.getHomeData();
      when(
        () => discover(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('network_error')));
      await cubit.getHomeData();
      expect(cubit.state.status, HomeStatus.failure);
      expect(cubit.state.isLoungesLoading, false);
      expect(cubit.state.nearestLounges, [lounge]);
    },
  );
  test(
    'late old-location response cannot overwrite a newer result or its cache',
    () async {
      final old = Completer<Either<Failure, List<LoungeModel>>>();
      final newer = LoungeModel.fromJson({'id': 'new'});
      var calls = 0;
      when(() => discover(any())).thenAnswer(
        (_) => ++calls == 1 ? old.future : Future.value(Right([newer])),
      );
      final pending = cubit.getHomeData();
      lat = '30';
      lng = '31';
      await cubit.getHomeData();
      old.complete(Right([lounge]));
      await pending;
      expect(cubit.state.nearestLounges, [newer]);
      verify(() => pref.saveValue('CACHED_LOUNGES', any())).called(1);
    },
  );
  test(
    'movement threshold refreshes distance while small movement avoids repeated RPC calls',
    () async {
      lat = '30';
      lng = '31';
      await cubit.getHomeData();
      cubit.startLocationListening();
      cubit.startLocationListening();
      positions.add(position(30.0001, 31.0001));
      await flush();
      verify(() => discover(any())).called(1);
      positions.add(position(30.01, 31.01));
      await flush();
      final params =
          verify(() => discover(captureAny())).captured.single
              as GetLoungesParams;
      expect(params.lat, 30.01);
      expect(params.lng, 31.01);
      cubit.stopLocationListening();
      positions.add(position(31, 32));
      await flush();
      verifyNever(() => discover(any()));
    },
  );
  test(
    'late bootstrap GPS does not overwrite a newer stream position',
    () async {
      final gps = Completer<Position?>();
      when(() => location.getCurrentLocation()).thenAnswer((_) => gps.future);
      final initializing = cubit.init();
      cubit.startLocationListening();
      positions.add(position(31, 32));
      await flush();
      gps.complete(position(30, 31));
      await initializing;
      await flush();
      expect(pref.latitude(), '31.0');
      expect(pref.longitude(), '32.0');
      final calls = verify(
        () => discover(captureAny()),
      ).captured.cast<GetLoungesParams>();
      expect(calls.last.lat, 31);
      expect(calls.last.lng, 32);
    },
  );
  test(
    'position stream errors are contained and explicit resume can subscribe again',
    () async {
      cubit.startLocationListening();
      positions.addError(StateError('permission denied'));
      await flush();
      cubit.startLocationListening();
      positions.add(position(30, 31));
      await flush();
      verify(() => discover(any())).called(1);
      await cubit.close();
      positions.add(position(31, 32));
      await flush();
      verifyNever(() => discover(any()));
    },
  );
  test(
    'coordinate writes serialize and requests always see a complete latest pair',
    () async {
      final block = Completer<void>();
      var calls = 0;
      when(() => pref.saveLatitude(any())).thenAnswer((call) async {
        if (++calls == 1) await block.future;
        lat = '${call.positionalArguments.first}';
      });
      final tracker = HomeLocationTracker(pref);
      final old = tracker.save(position(30, 31));
      await flush();
      final newer = tracker.save(position(32, 33));
      expect(tracker.coordinates?.latitude, 32);
      expect(tracker.coordinates?.longitude, 33);
      block.complete();
      expect(await old, false);
      expect(await newer, true);
      expect(pref.latitude(), '32.0');
      expect(pref.longitude(), '33.0');
    },
  );
  test(
    'offline movement updates cached venue distance and labels it as an estimate',
    () async {
      lat = '30';
      lng = '31';
      final venue = LoungeModel.fromJson({
        'id': 'venue',
        'latitude': 30.01,
        'longitude': 31.01,
        'distance_km': 2,
      });
      when(() => discover(any())).thenAnswer((_) async => Right([venue]));
      await cubit.getHomeData();
      expect(cubit.state.nearestLounges.single.distanceIsApproximate, false);
      when(
        () => discover(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('network_error')));
      cubit.startLocationListening();
      positions.add(position(30.01, 31.01));
      await flush();
      final estimated = cubit.state.nearestLounges.single;
      expect(estimated.distance, 0);
      expect(estimated.distanceIsApproximate, true);
      expect(estimated.getFormattedDistance(isArabic: false), '≈ 0 m');
      expect(cubit.state.isLoungesLoading, false);
      final fresh = LoungeModel.fromJson({
        'id': 'venue',
        'latitude': 30.01,
        'longitude': 31.01,
        'distance_km': 0.12,
      });
      when(() => discover(any())).thenAnswer((_) async => Right([fresh]));
      await cubit.getHomeData();
      expect(cubit.state.nearestLounges.single.distanceIsApproximate, false);
      expect(cubit.state.nearestLounges.single.distance, 0.12);
    },
  );
}
