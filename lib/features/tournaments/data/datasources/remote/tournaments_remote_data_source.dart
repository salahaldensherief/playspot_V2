import 'dart:developer' as dev;
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/tournament_model.dart';

abstract class TournamentsRemoteDataSource {
  Future<List<TournamentModel>> getTournaments({
    String? game,
    String? cityId,
    String? statusFilter,
    String? searchQuery,
  });

  Future<TournamentModel> getTournamentById(String tournamentId);

  Future<List<TournamentPrizeModel>> getTournamentPrizes(String tournamentId);

  Future<List<TournamentMatchModel>> getTournamentMatches(String tournamentId);

  Future<TournamentParticipantModel?> getUserParticipant(
    String tournamentId,
    String userId,
  );

  Future<Map<String, dynamic>> registerForTournament(String tournamentId);

  Future<void> submitTournamentPayment({
    required String participantId,
    required String tournamentId,
    required String userId,
    required double amount,
    required String paymentMethod,
    required File receiptFile,
  });

  Future<void> checkInParticipant(String participantId);

  Future<void> submitMatchResult({
    required String matchId,
    required String tournamentId,
    required int player1Score,
    required int player2Score,
    File? proofFile,
  });

  Future<void> confirmMatchResult(String matchId);

  Future<void> disputeMatchResult({
    required String matchId,
    required String disputeReason,
  });

  Stream<List<TournamentMatchModel>> watchTournamentMatches(String tournamentId);

  Future<void> updateFcmToken(String token);
}

class TournamentsRemoteDataSourceImpl implements TournamentsRemoteDataSource {
  final SupabaseClient _client;

  TournamentsRemoteDataSourceImpl(this._client);

  @override
  Future<List<TournamentModel>> getTournaments({
    String? game,
    String? cityId,
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('tournaments').select('''
        *,
        cities (name),
        lounges (name),
        tournament_participants (id)
      ''');

      if (game != null && game.isNotEmpty && game != 'All') {
        query = query.ilike('game', '%$game%');
      }

      if (cityId != null && cityId.isNotEmpty) {
        query = query.eq('city_id', cityId);
      }

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        query = query.eq('status', statusFilter);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('title', '%${searchQuery.trim()}%');
      }

      final response = await query.order('created_at', ascending: false);
      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((json) => TournamentModel.fromJson(json)).toList();
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error fetching tournaments: $e');
      // Fallback query if relation joins fail
      var fallbackQuery = _client.from('tournaments').select();
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        fallbackQuery = fallbackQuery.eq('status', statusFilter);
      }
      final response = await fallbackQuery.order('created_at', ascending: false);
      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((json) => TournamentModel.fromJson(json)).toList();
    }
  }

  @override
  Future<TournamentModel> getTournamentById(String tournamentId) async {
    final response = await _client.from('tournaments').select('''
      *,
      cities (name),
      lounges (name),
      tournament_participants (id)
    ''').eq('id', tournamentId).single();

    return TournamentModel.fromJson(response);
  }

  @override
  Future<List<TournamentPrizeModel>> getTournamentPrizes(String tournamentId) async {
    try {
      final response = await _client
          .from('tournament_prizes')
          .select()
          .eq('tournament_id', tournamentId)
          .order('placement', ascending: true);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((json) => TournamentPrizeModel.fromJson(json)).toList();
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error fetching prizes: $e');
      return [];
    }
  }

  @override
  Future<List<TournamentMatchModel>> getTournamentMatches(String tournamentId) async {
    try {
      final response = await _client
          .from('tournament_matches')
          .select('''
            *,
            player1:profiles!tournament_matches_player1_id_fkey(full_name, avatar_url),
            player2:profiles!tournament_matches_player2_id_fkey(full_name, avatar_url)
          ''')
          .eq('tournament_id', tournamentId)
          .order('round_number', ascending: true)
          .order('match_order', ascending: true);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((json) => TournamentMatchModel.fromJson(json)).toList();
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Flat match query fallback due to join error: $e');
      final response = await _client
          .from('tournament_matches')
          .select()
          .eq('tournament_id', tournamentId)
          .order('round_number', ascending: true)
          .order('match_order', ascending: true);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((json) => TournamentMatchModel.fromJson(json)).toList();
    }
  }

  @override
  Future<TournamentParticipantModel?> getUserParticipant(
    String tournamentId,
    String userId,
  ) async {
    try {
      final response = await _client
          .from('tournament_participants')
          .select('*, profiles(full_name, avatar_url)')
          .eq('tournament_id', tournamentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return TournamentParticipantModel.fromJson(response);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error fetching user participant: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> registerForTournament(String tournamentId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not logged in');
    }

    try {
      final res = await _client.rpc(
        'register_for_tournament',
        params: {
          'p_tournament_id': tournamentId,
          'p_user_id': currentUser.id,
        },
      );

      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'participant_id': res?.toString()};
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC register_for_tournament error: $e');
      // Direct fallback insert if RPC is unavailable
      final insertRes = await _client.from('tournament_participants').insert({
        'tournament_id': tournamentId,
        'user_id': currentUser.id,
        'status': 'pending_payment',
        'payment_status': 'unpaid',
        'checked_in': false,
      }).select().single();

      return TournamentParticipantModel.fromJson(insertRes).toJson();
    }
  }

  @override
  Future<void> submitTournamentPayment({
    required String participantId,
    required String tournamentId,
    required String userId,
    required double amount,
    required String paymentMethod,
    required File receiptFile,
  }) async {
    final fileExt = receiptFile.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final storagePath = 'tournament-receipts/$tournamentId/$userId/$fileName';

    final bytes = await receiptFile.readAsBytes();
    await _client.storage.from('tournament-receipts').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$fileExt',
            upsert: true,
          ),
        );

    final signedUrl = await _client.storage
        .from('tournament-receipts')
        .createSignedUrl(storagePath, 60 * 60 * 24 * 365); // 1 year signed URL

    try {
      await _client.rpc(
        'submit_tournament_payment',
        params: {
          'p_participant_id': participantId,
          'p_amount': amount,
          'p_payment_method': paymentMethod,
          'p_receipt_url': signedUrl,
        },
      );
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC submit_tournament_payment error: $e');
      await _client.from('tournament_participants').update({
        'payment_status': 'pending_verification',
        'payment_method': paymentMethod,
        'receipt_url': signedUrl,
      }).eq('id', participantId);
    }
  }

  @override
  Future<void> checkInParticipant(String participantId) async {
    try {
      await _client.rpc(
        'check_in_tournament_participant',
        params: {'p_participant_id': participantId},
      );
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC check_in_tournament_participant error: $e');
      await _client.from('tournament_participants').update({
        'checked_in': true,
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'confirmed',
      }).eq('id', participantId);
    }
  }

  @override
  Future<void> submitMatchResult({
    required String matchId,
    required String tournamentId,
    required int player1Score,
    required int player2Score,
    File? proofFile,
  }) async {
    final currentUser = _client.auth.currentUser;
    String? proofUrl;

    if (proofFile != null) {
      final fileExt = proofFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storagePath = 'tournament-result-proofs/$tournamentId/$matchId/$fileName';

      final bytes = await proofFile.readAsBytes();
      await _client.storage.from('tournament-result-proofs').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true,
            ),
          );

      proofUrl = await _client.storage
          .from('tournament-result-proofs')
          .createSignedUrl(storagePath, 60 * 60 * 24 * 365);
    }

    try {
      await _client.rpc(
        'submit_match_result',
        params: {
          'p_match_id': matchId,
          'p_player1_score': player1Score,
          'p_player2_score': player2Score,
          'p_proof_url': proofUrl,
        },
      );
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC submit_match_result error: $e');
      final deadline = DateTime.now().add(const Duration(minutes: 5)).toUtc();
      await _client.from('tournament_matches').update({
        'player1_score': player1Score,
        'player2_score': player2Score,
        'status': 'pending_confirmation',
        'proof_url': proofUrl,
        'submitted_by': currentUser?.id,
        'confirmation_deadline': deadline.toIso8601String(),
      }).eq('id', matchId);
    }
  }

  @override
  Future<void> confirmMatchResult(String matchId) async {
    try {
      await _client.rpc(
        'confirm_match_result',
        params: {'p_match_id': matchId},
      );
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC confirm_match_result error: $e');
      await _client.from('tournament_matches').update({
        'status': 'completed',
      }).eq('id', matchId);
    }
  }

  @override
  Future<void> disputeMatchResult({
    required String matchId,
    required String disputeReason,
  }) async {
    try {
      await _client.rpc(
        'dispute_match_result',
        params: {
          'p_match_id': matchId,
          'p_dispute_reason': disputeReason,
        },
      );
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC dispute_match_result error: $e');
      await _client.from('tournament_matches').update({
        'status': 'disputed',
        'dispute_reason': disputeReason,
      }).eq('id', matchId);
    }
  }

  @override
  Stream<List<TournamentMatchModel>> watchTournamentMatches(String tournamentId) {
    return _client
        .from('tournament_matches')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', tournamentId)
        .order('round_number', ascending: true)
        .order('match_order', ascending: true)
        .map((list) => list.map((json) => TournamentMatchModel.fromJson(json)).toList());
  }

  @override
  Future<void> updateFcmToken(String token) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || token.isEmpty) return;

    try {
      await _client.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', currentUser.id);
    } catch (e) {
      // Silent error - rule 12: no token logging
    }
  }
}
