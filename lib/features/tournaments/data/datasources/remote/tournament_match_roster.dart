import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/tournament_model.dart';

/// Spectators can read public matches without access to private participant names.
/// A name authorization denial keeps the public bracket; other failures propagate.
Future<List<TournamentMatchModel>> mapTournamentMatchesWithNames(
  SupabaseClient client,
  String tournamentId,
  List<Map<String, dynamic>> rows,
) async {
  final names = <String, String>{};
  if (rows.any((r) => r['player1_id'] != null || r['player2_id'] != null)) {
    try {
      final response = await client.rpc(
        'get_tournament_participant_names',
        params: {'p_tournament_id': tournamentId},
      );
      if (response is! List) {
        throw const FormatException('Invalid tournament roster');
      }
      for (final row in response) {
        if (row is! Map || row['participant_id'] is! String) {
          throw const FormatException('Invalid tournament participant name');
        }
        final name = (row['user_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          names[row['participant_id'] as String] = name;
        }
      }
    } on PostgrestException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }
  return rows
      .map(
        (row) => TournamentMatchModel.fromJson({
          ...row,
          if (names[row['player1_id']] != null)
            'player1_name': names[row['player1_id']],
          if (names[row['player2_id']] != null)
            'player2_name': names[row['player2_id']],
        }),
      )
      .toList();
}
