import 'dart:developer' as dev;
import 'dart:io';
import 'tournament_evidence_upload.dart';

import 'package:playspot/core/models/paginated_response.dart';
import 'package:playspot/features/tournaments/domain/entities/tournament_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/tournament_model.dart';
import '../../models/user_tournament_participation_model.dart';

abstract class TournamentsRemoteDataSource {
  Future<List<TournamentModel>> getTournaments({
    String? game,
    String? cityId,
    String? statusFilter,
    String? searchQuery,
    double? latitude,
    double? longitude,
    String? loungeId,
  });

  Future<TournamentModel> getTournamentById(String tournamentId);

  Future<List<TournamentPrizeModel>> getTournamentPrizes(String tournamentId);

  Future<List<TournamentMatchModel>> getTournamentMatches(String tournamentId);

  Future<TournamentMatchModel?> getMatchById(
    String tournamentId,
    String matchId,
  );

  Future<TournamentParticipantModel?> getUserParticipant(
    String tournamentId,
    String userId,
  );

  Future<TournamentParticipantModel?> registerForTournament(
    String tournamentId,
  );

  Future<TournamentParticipantModel?> submitTournamentPayment({
    required String participantId,
    required String tournamentId,
    required String userId,
    required double amount,
    required String paymentMethod,
    required File receiptFile,
  });

  Future<TournamentParticipantModel?> checkInParticipant(String participantId);

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

  Stream<List<TournamentMatchModel>> watchTournamentMatches(
    String tournamentId,
  );

  Future<PaginatedResponse<Map<String, dynamic>>> getTournamentAuditLogsPage({
    required String tournamentId,
    int page = 1,
    int pageSize = 50,
  });

  Future<TournamentParticipantModel?> withdrawFromTournament(
    String participantId, {
    String? tournamentId,
  });

  Future<List<Map<String, dynamic>>> getUserTournamentHistory(String userId);

  Future<TournamentModel?> getHomeTournament();

  Future<UserTournamentParticipationModel?> getMyActiveTournament();

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
    double? latitude,
    double? longitude,
    String? loungeId,
  }) async {
    final response = await _client.rpc(
      'get_visible_tournaments',
      params: {'p_latitude': latitude, 'p_longitude': longitude},
    );

    final list = (response as List).cast<Map<String, dynamic>>();
    var models = list.map(TournamentModel.fromJson).toList();

    if (statusFilter == 'completed') {
      return const <TournamentModel>[];
    }

    if (loungeId != null && loungeId.isNotEmpty) {
      models = models.where((t) => t.loungeId == loungeId).toList();
    }

    if (game != null && game.isNotEmpty && game != 'All') {
      final cleanGame = game.toLowerCase();
      models = models
          .where((t) => t.game.toLowerCase().contains(cleanGame))
          .toList();
    }

    if (cityId != null && cityId.isNotEmpty) {
      models = models.where((t) {
        if (t.visibilityScope == TournamentVisibilityScope.all) return true;
        return t.cityId == cityId;
      }).toList();
    }

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'All') {
      models = models.where((t) {
        final dbStatus = t.status.toDbString();
        if (statusFilter == 'registration_open') {
          return dbStatus == 'registration_open' || dbStatus == 'published';
        }
        return dbStatus == statusFilter;
      }).toList();
    }

    final query = searchQuery?.trim().toLowerCase() ?? '';
    if (query.isNotEmpty) {
      models = models.where((t) {
        return (t.titleAr ?? '').toLowerCase().contains(query) ||
            (t.titleEn ?? '').toLowerCase().contains(query) ||
            t.title.toLowerCase().contains(query) ||
            t.game.toLowerCase().contains(query) ||
            (t.descriptionAr ?? '').toLowerCase().contains(query) ||
            (t.descriptionEn ?? '').toLowerCase().contains(query);
      }).toList();
    }

    return models;
  }

  @override
  Future<TournamentModel> getTournamentById(String tournamentId) async {
    try {
      final response = await _client
          .from('tournaments')
          .select('*, cities:city_id(*), lounges:lounge_id(*)')
          .eq('id', tournamentId)
          .single();
      return TournamentModel.fromJson(response);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error in getTournamentById: $e');
      rethrow;
    }
  }

  @override
  Future<List<TournamentPrizeModel>> getTournamentPrizes(
    String tournamentId,
  ) async {
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
  Future<List<TournamentMatchModel>> getTournamentMatches(
    String tournamentId,
  ) async {
    try {
      final response = await _client
          .from('tournament_matches')
          .select()
          .eq('tournament_id', tournamentId)
          .order('round_number', ascending: true)
          .order('match_order', ascending: true);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((json) => TournamentMatchModel.fromJson(json)).toList();
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error in getTournamentMatches: $e');
      return [];
    }
  }

  @override
  Future<TournamentMatchModel?> getMatchById(
    String tournamentId,
    String matchId,
  ) async {
    try {
      final response = await _client
          .from('tournament_matches')
          .select()
          .eq('id', matchId)
          .maybeSingle();

      if (response != null) {
        return TournamentMatchModel.fromJson(response);
      }
      return null;
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error in getMatchById: $e');
      return null;
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
          .select()
          .eq('tournament_id', tournamentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return TournamentParticipantModel.fromJson(response);
      }
      return null;
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error fetching user participant: $e');
      return null;
    }
  }

  @override
  Future<UserTournamentParticipationModel?> getMyActiveTournament() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return null;

      final response = await _client
          .from('tournament_participants')
          .select('*, tournaments(*)')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return UserTournamentParticipationModel.fromJson(response);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error in getMyActiveTournament: $e');
      return null;
    }
  }

  @override
  Future<TournamentParticipantModel?> registerForTournament(
    String tournamentId,
  ) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not logged in');
    }

    try {
      final res = await _client.rpc(
        'register_for_tournament',
        params: {'p_tournament_id': tournamentId},
      );

      if (res is Map<String, dynamic>) {
        return TournamentParticipantModel.fromJson(res);
      }
      return await getUserParticipant(tournamentId, currentUser.id);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC register_for_tournament error: $e');
      rethrow;
    }
  }

  @override
  Future<TournamentParticipantModel?> submitTournamentPayment({
    required String participantId,
    required String tournamentId,
    required String userId,
    required double amount,
    required String paymentMethod,
    required File receiptFile,
  }) async {
    final upload = TournamentEvidenceUpload(tournamentId: tournamentId,
        scopeId: userId, filePath: receiptFile.path);
    final storagePath = upload.path;

    final bytes = await receiptFile.readAsBytes();
    await _client.storage
        .from('tournament-receipts')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: upload.options,
        );

    final signedUrl = await _client.storage
        .from('tournament-receipts')
        .createSignedUrl(storagePath, 60 * 60 * 24 * 365);

    try {
      final res = await _client.rpc(
        'submit_tournament_payment',
        params: {
          'p_participant_id': participantId,
          'p_amount': amount,
          'p_payment_method': paymentMethod,
          'p_receipt_url': signedUrl,
        },
      );

      if (res is Map<String, dynamic>) {
        return TournamentParticipantModel.fromJson(res);
      }
      return await getUserParticipant(tournamentId, userId);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC submit_tournament_payment error: $e');
      rethrow;
    }
  }

  @override
  Future<TournamentParticipantModel?> checkInParticipant(
    String participantId,
  ) async {
    try {
      final res = await _client.rpc(
        'check_in_tournament_participant',
        params: {'p_participant_id': participantId},
      );

      if (res is Map<String, dynamic>) {
        return TournamentParticipantModel.fromJson(res);
      }
      return null;
    } catch (e) {
      dev.log(
        '[TOURNAMENTS_REMOTE] RPC check_in_tournament_participant error: $e',
      );
      rethrow;
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
    if (currentUser == null) {
      throw Exception('User not logged in');
    }

    String? proofUrl;

    if (proofFile != null) {
      final upload = TournamentEvidenceUpload(tournamentId: tournamentId,
          scopeId: matchId, filePath: proofFile.path);
      final storagePath = upload.path;

      final bytes = await proofFile.readAsBytes();
      await _client.storage
          .from('tournament-result-proofs')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: upload.options,
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
          'p_score_player1': player1Score,
          'p_score_player2': player2Score,
          'p_proof_image_url': proofUrl,
        },
      );
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC submit_match_result error: $e');
      rethrow;
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
      rethrow;
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
        params: {'p_match_id': matchId, 'p_reason': disputeReason},
      );
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC dispute_match_result error: $e');
      rethrow;
    }
  }

  @override
  Stream<List<TournamentMatchModel>> watchTournamentMatches(
    String tournamentId,
  ) {
    return _client
        .from('tournament_matches')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', tournamentId)
        .order('round_number', ascending: true)
        .order('match_order', ascending: true)
        .map(
          (list) =>
              list.map((json) => TournamentMatchModel.fromJson(json)).toList(),
        );
  }

  @override
  Future<PaginatedResponse<Map<String, dynamic>>> getTournamentAuditLogsPage({
    required String tournamentId,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await _client.rpc(
        'get_tournament_audit_logs_page',
        params: {
          'p_tournament_id': tournamentId,
          'p_page': page,
          'p_page_size': pageSize,
        },
      );

      return PaginatedResponse.fromRpc(
        response: response,
        fromJson: (json) => json,
        requestedPage: page,
        requestedPageSize: pageSize,
      );
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] get_tournament_audit_logs_page error: $e');
      return PaginatedResponse(
        items: const [],
        totalCount: 0,
        page: page,
        pageSize: pageSize,
      );
    }
  }

  @override
  Future<void> updateFcmToken(String token) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || token.isEmpty) return;

    try {
      await _client
          .from('profiles')
          .update({
            'fcm_token': token,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', currentUser.id);
    } catch (e) {
      // Silent error for FCM token update
    }
  }

  @override
  Future<TournamentParticipantModel?> withdrawFromTournament(
    String participantId, {
    String? tournamentId,
  }) async {
    if (tournamentId == null || tournamentId.isEmpty) {
      throw ArgumentError('tournamentId is required for tournament withdrawal');
    }

    final res = await _client.rpc(
      'withdraw_from_tournament',
      params: {'p_tournament_id': tournamentId},
    );

    if (res is Map<String, dynamic>) {
      return TournamentParticipantModel.fromJson(res);
    }
    if (res is Map) {
      return TournamentParticipantModel.fromJson(
        Map<String, dynamic>.from(res),
      );
    }

    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getUserTournamentHistory(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('tournament_participants')
          .select('*, tournaments(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      dev.log(
        '[TOURNAMENTS_REMOTE] Error fetching user tournament history: $e',
      );
      return [];
    }
  }

  @override
  Future<TournamentModel?> getHomeTournament() async {
    try {
      final response = await _client.rpc('get_home_tournament');
      if (response == null) return null;
      if (response is List) {
        if (response.isEmpty) return null;
        return TournamentModel.fromJson(
          (response.first as Map).cast<String, dynamic>(),
        );
      }
      if (response is Map) {
        return TournamentModel.fromJson(response.cast<String, dynamic>());
      }
      return null;
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC get_home_tournament error: $e');
      return null;
    }
  }
}
