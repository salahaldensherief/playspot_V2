import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/features/tournaments/data/datasources/remote/tournaments_remote_data_source.dart';
import 'package:playspot/features/tournaments/domain/entities/tournament_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<dynamic> {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late TournamentsRemoteDataSource dataSource;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    dataSource = TournamentsRemoteDataSourceImpl(mockSupabase);
  });

  group('Batch 1 — Tournaments Data & Domain Unit Tests', () {
    test('dispute uses the deployed reason parameter without retry', () async {
      when(() => mockSupabase.rpc('dispute_match_result', params: any(named: 'params')))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.then<dynamic>(any(), onError: any(named: 'onError')))
          .thenAnswer((invocation) async {
            final callback = invocation.positionalArguments.first as Function;
            return callback({'success': true});
          });
      await dataSource.disputeMatchResult(matchId: 'match', disputeReason: 'Wrong score');
      verify(() => mockSupabase.rpc('dispute_match_result', params: {
        'p_match_id': 'match', 'p_reason': 'Wrong score',
      })).called(1);
    });

    test('TournamentStatus fromString parses valid and fallback statuses', () {
      expect(TournamentStatus.fromString('registration_open'), equals(TournamentStatus.registrationOpen));
      expect(TournamentStatus.fromString('completed'), equals(TournamentStatus.completed));
      expect(TournamentStatus.fromString('invalid_status'), equals(TournamentStatus.registrationOpen));
    });

    test('ParticipantStatus toLocalizedName returns localized key string', () {
      expect(ParticipantStatus.confirmed.toLocalizedName(), isNotEmpty);
      expect(ParticipantStatus.pendingPayment.toLocalizedName(), isNotEmpty);
    });

    test('getTournaments handles empty RPC response gracefully', () async {
      when(() => mockSupabase.rpc('get_visible_tournaments', params: any(named: 'params')))
          .thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.then<dynamic>(any(), onError: any(named: 'onError')))
          .thenAnswer((invocation) async {
            final callback = invocation.positionalArguments.first as Function;
            return callback([]);
          });

      final result = await dataSource.getTournaments();

      expect(result, isEmpty);
    });
  });
}
