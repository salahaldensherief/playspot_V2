import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:playspot/core/services/location_service.dart';
import 'package:playspot/features/tournaments/domain/entities/tournament_entity.dart';
import 'package:playspot/features/tournaments/domain/usecases/get_tournaments_usecase.dart';
import 'package:playspot/features/tournaments/presentation/tournaments_feed/tournaments_feed_cubit.dart';
import 'package:playspot/features/tournaments/presentation/tournaments_feed/tournaments_feed_state.dart';

class MockGetTournamentsUseCase extends Mock implements GetTournamentsUseCase {}
class MockLocationService extends Mock implements LocationService {}

void main() {
  late MockGetTournamentsUseCase mockGetTournamentsUseCase;
  late MockLocationService mockLocationService;
  late TournamentsFeedCubit cubit;

  const testTournament = TournamentEntity(
    id: 't_1',
    title: 'FC 24 Championship',
    game: 'EA FC 24',
    status: TournamentStatus.registrationOpen,
    maxParticipants: 16,
    registeredParticipantsCount: 4,
    bracketSize: 16,
    entryFee: 100.0,
  );

  setUp(() {
    mockGetTournamentsUseCase = MockGetTournamentsUseCase();
    mockLocationService = MockLocationService();

    when(() => mockLocationService.getCurrentLocation()).thenAnswer((_) async => null);

    cubit = TournamentsFeedCubit(mockGetTournamentsUseCase, mockLocationService);
  });

  tearDown(() {
    if (!cubit.isClosed) {
      cubit.close();
    }
  });

  group('Batch 2 — TournamentsFeedCubit Unit Tests', () {
    test('initial state is correct', () {
      expect(cubit.state.status, equals(TournamentsFeedStatus.initial));
      expect(cubit.state.tournaments, isEmpty);
    });

    test('loadTournaments emits [loading, success] on successful fetch', () async {
      when(() => mockGetTournamentsUseCase(
            game: any(named: 'game'),
            cityId: any(named: 'cityId'),
            statusFilter: any(named: 'statusFilter'),
            searchQuery: any(named: 'searchQuery'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => const Right([testTournament]));

      await cubit.loadTournaments();

      expect(cubit.state.status, equals(TournamentsFeedStatus.success));
      expect(cubit.state.tournaments, hasLength(1));
      expect(cubit.state.availableGames, contains('EA FC 24'));
    });
  });
}
