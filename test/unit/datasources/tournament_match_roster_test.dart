import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playspot/features/tournaments/data/datasources/remote/tournaments_remote_data_source.dart';

void main() {
  late SupabaseClient client;
  late List<http.Request> requests;
  var rosterCode = 200;
  var matchCode = 200;
  var malformedRoster = false;
  setUp(() {
    rosterCode = 200;
    matchCode = 200;
    malformedRoster = false;
    requests = [];
    client = SupabaseClient(
      'https://fixture.invalid',
      'fixture-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final roster = request.url.path.endsWith(
          '/get_tournament_participant_names',
        );
        final status = roster ? rosterCode : matchCode;
        final Object body = status >= 400
            ? {
                'code': status == 403 ? '42501' : 'XX000',
                'message': 'fixture error',
              }
            : roster
            ? malformedRoster
                  ? {}
                  : [
                      {'participant_id': 'p1', 'user_name': 'Alpha'},
                      {'participant_id': 'p2', 'user_name': 'Bravo'},
                    ]
            : [
                {
                  'id': 'm1',
                  'tournament_id': 't1',
                  'round_number': 3,
                  'match_order': 2,
                  'match_type': 'third_place',
                  'player1_id': 'p1',
                  'player2_id': 'p2',
                  'status': 'scheduled',
                },
              ];
        // PostgREST singular requests return an object; lists retain their array shape.
        final singular =
            request.headers['Accept']?.contains('vnd.pgrst.object') ?? false;
        return http.Response(
          jsonEncode(
            !roster && singular && status == 200 ? (body as List).single : body,
          ),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDown(() => client.dispose());
  test(
    'authorized participant sees scoped display names and bronze type',
    () async {
      final matches = await TournamentsRemoteDataSourceImpl(
        client,
      ).getTournamentMatches('t1');
      expect(matches.single.player1Name, 'Alpha');
      expect(matches.single.player2Name, 'Bravo');
      expect(matches.single.isThirdPlace, isTrue);
      expect(requests.any((r) => r.url.path.endsWith('/profiles')), isFalse);
      expect(jsonDecode(requests.last.body), {'p_tournament_id': 't1'});
    },
  );
  test(
    'spectator name denial preserves the public bracket without private names',
    () async {
      rosterCode = 403;
      final matches = await TournamentsRemoteDataSourceImpl(
        client,
      ).getTournamentMatches('t1');
      expect(matches, hasLength(1));
      expect(matches.single.player1Name, isNull);
    },
  );
  test(
    'a failed roster request is visible rather than fabricated empty matches',
    () async {
      rosterCode = 500;
      await expectLater(
        TournamentsRemoteDataSourceImpl(client).getTournamentMatches('t1'),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
  test(
    'a denied match request propagates instead of pretending the bracket is empty',
    () async {
      matchCode = 403;
      await expectLater(
        TournamentsRemoteDataSourceImpl(client).getTournamentMatches('t1'),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests, hasLength(1));
    },
  );
  test(
    'malformed authorized names response is an explicit contract failure',
    () async {
      malformedRoster = true;
      await expectLater(
        TournamentsRemoteDataSourceImpl(client).getTournamentMatches('t1'),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test('single match reads are scoped to both match and tournament', () async {
    await TournamentsRemoteDataSourceImpl(client).getMatchById('t1', 'm1');
    expect(requests.first.url.queryParameters['id'], 'eq.m1');
    expect(requests.first.url.queryParameters['tournament_id'], 'eq.t1');
  });
}
