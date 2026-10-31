import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/tournaments/domain/entities/tournament_entity.dart';
import 'package:playspot/features/tournaments/domain/usecases/check_in_participant_usecase.dart';
import 'package:playspot/features/tournaments/domain/usecases/get_tournament_details_usecase.dart';
import 'package:playspot/features/tournaments/domain/usecases/register_tournament_usecase.dart';
import 'package:playspot/features/tournaments/domain/usecases/submit_tournament_payment_usecase.dart';
import 'package:playspot/features/tournaments/domain/usecases/watch_tournament_matches_usecase.dart';
import 'package:playspot/features/tournaments/domain/usecases/withdraw_tournament_usecase.dart';
import 'package:playspot/features/tournaments/presentation/tournament_details/tournament_details_cubit.dart';
import 'package:playspot/features/tournaments/presentation/tournament_details/tournament_details_state.dart';
import '../../support/mock_tournaments_repository.dart';

void main() {
  late MockTournamentsRepository repository;
  late TournamentDetailsCubit cubit;
  late StreamController<List<TournamentMatchEntity>> updates;
  const tournament = TournamentEntity(
    id: 't1',
    title: 'QA Cup',
    game: 'EA FC',
    status: TournamentStatus.drawCompleted,
    maxParticipants: 8,
    registeredParticipantsCount: 8,
    bracketSize: 8,
    entryFee: 100,
  );
  setUp(() {
    repository = MockTournamentsRepository();
    updates = StreamController<List<TournamentMatchEntity>>.broadcast();
    when(
      () => repository.getTournamentById(any()),
    ).thenAnswer((_) async => const Right(tournament));
    when(
      () => repository.getTournamentPrizes(any()),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => repository.getTournamentMatches(any()),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => repository.watchTournamentMatches(any()),
    ).thenAnswer((_) => updates.stream);
    cubit = TournamentDetailsCubit(
      GetTournamentDetailsUseCase(repository),
      RegisterTournamentUseCase(repository),
      SubmitTournamentPaymentUseCase(repository),
      CheckInParticipantUseCase(repository),
      WatchTournamentMatchesUseCase(repository),
      WithdrawTournamentUseCase(repository),
      currentUserId: () => null,
    );
  });
  tearDown(() async {
    await cubit.close();
    await updates.close();
  });
  test('a bracket failure exits loading and exposes the error', () async {
    when(
      () => repository.getTournamentMatches('t1'),
    ).thenAnswer((_) async => const Left(ServerFailure('Bracket unavailable')));
    await cubit.init('t1');
    expect(cubit.state.status, TournamentDetailsStatus.failure);
    expect(cubit.state.errorMessage, 'Bracket unavailable');
    verifyNever(() => repository.watchTournamentMatches(any()));
  });
  test(
    'a prizes failure exits loading rather than leaving a permanent spinner',
    () async {
      when(() => repository.getTournamentPrizes('t1')).thenAnswer(
        (_) async => const Left(ServerFailure('Prizes unavailable')),
      );
      await cubit.init('t1');
      expect(cubit.state.status, TournamentDetailsStatus.failure);
      expect(cubit.state.errorMessage, 'Prizes unavailable');
    },
  );
  test('a realtime failure is visible while retaining loaded data', () async {
    await cubit.init('t1');
    final next = cubit.stream.firstWhere((s) => s.errorMessage != null);
    updates.addError(StateError('fixture network failure'));
    final state = await next;
    expect(state.tournament, tournament);
    expect(state.status, TournamentDetailsStatus.success);
    expect(state.errorMessage, isNotEmpty);
  });
  test('a late load cannot replace a newer selected tournament', () async {
    final delayed = Completer<Either<Failure, TournamentEntity>>();
    when(
      () => repository.getTournamentById('old'),
    ).thenAnswer((_) => delayed.future);
    final old = cubit.init('old');
    await cubit.init('t1');
    delayed.complete(const Left(ServerFailure('Stale error')));
    await old;
    expect(cubit.state.status, TournamentDetailsStatus.success);
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.tournament?.id, 't1');
  });
}
