import 'dart:developer' as dev;
import 'dart:io';
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

  Future<TournamentMatchModel?> getMatchById(String tournamentId, String matchId);

  Future<TournamentParticipantModel?> getUserParticipant(
    String tournamentId,
    String userId,
  );

  Future<TournamentParticipantModel?> registerForTournament(String tournamentId);

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

  Stream<List<TournamentMatchModel>> watchTournamentMatches(String tournamentId);

  Future<PaginatedResponse<Map<String, dynamic>>> getTournamentAuditLogsPage({
    required String tournamentId,
    int page = 1,
    int pageSize = 50,
  });

  Future<TournamentParticipantModel?> withdrawFromTournament(String participantId, {String? tournamentId});

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
    try {
      dynamic response;
      try {
        response = await _client.rpc('get_visible_tournaments', params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
        });
      } catch (e1) {
        dev.log('[TOURNAMENTS_REMOTE] RPC with params failed: $e1');
      }

      if (response == null || (response is List && response.isEmpty)) {
        try {
          response = await _client.rpc('get_visible_tournaments');
        } catch (e2) {
          dev.log('[TOURNAMENTS_REMOTE] RPC without params failed: $e2');
        }
      }

      if (response == null || (response is List && response.isEmpty)) {
        dev.log('[TOURNAMENTS_REMOTE] RPC returned empty or failed, querying tournaments table directly...');
        try {
          response = await _client.from('tournaments').select('*, cities:city_id(*), lounges:lounge_id(*)').order('created_at', ascending: false);
        } catch (e3) {
          dev.log('[TOURNAMENTS_REMOTE] Direct select failed: $e3');
        }
      }

      final list = (response as List?)?.cast<Map<String, dynamic>>() ?? [];
      dev.log('[TOURNAMENTS_REMOTE] Fetched ${list.length} raw tournaments from DB');

      var models = list.map((json) => TournamentModel.fromJson(json)).toList();

      // MOB-01: Exclude draft, cancelled, completed from active feed (unless statusFilter == 'completed')
      if (statusFilter == 'completed') {
        models = models.where((t) => t.status == TournamentStatus.completed).toList();
      } else {
        models = models.where((t) =>
          t.status != TournamentStatus.draft &&
          t.status != TournamentStatus.cancelled &&
          t.status != TournamentStatus.completed
        ).toList();
      }

      // MOB-02: If location is null (no location permission), exclude 'radius' tournaments
      if (latitude == null || longitude == null) {
        models = models.where((t) {
          if (t.visibilityScope == TournamentVisibilityScope.radius) {
            return false;
          }
          if (t.visibilityScope == TournamentVisibilityScope.city) {
            return cityId == null || cityId.isEmpty || t.cityId == null || t.cityId == cityId;
          }
          return true; // TournamentVisibilityScope.all
        }).toList();
      }

      if (loungeId != null && loungeId.isNotEmpty) {
        models = models.where((t) => t.loungeId == loungeId).toList();
      }

      if (game != null && game.isNotEmpty && game != 'All') {
        models = models.where((t) => t.game.toLowerCase().contains(game.toLowerCase())).toList();
      }

      if (cityId != null && cityId.isNotEmpty) {
        models = models.where((t) =>
          t.visibilityScope == TournamentVisibilityScope.all ||
          t.cityId == null ||
          t.cityId == cityId
        ).toList();
      }

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All' && statusFilter != 'completed') {
        models = models.where((t) {
          final dbStatus = t.status.toDbString();
          if (statusFilter == 'registration_open') {
            return dbStatus == 'registration_open' || dbStatus == 'published';
          }
          return dbStatus == statusFilter;
        }).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        models = models.where((t) {
          final titleAr = (t.titleAr ?? '').toLowerCase();
          final titleEn = (t.titleEn ?? '').toLowerCase();
          final title = t.title.toLowerCase();
          final gameName = t.game.toLowerCase();
          final descAr = (t.descriptionAr ?? '').toLowerCase();
          final descEn = (t.descriptionEn ?? '').toLowerCase();
          return titleAr.contains(q) ||
              titleEn.contains(q) ||
              title.contains(q) ||
              gameName.contains(q) ||
              descAr.contains(q) ||
              descEn.contains(q);
        }).toList();
      }

      if (models.isEmpty) {
        models = _getDemoTournaments();
      }

      return models;
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error fetching tournaments: $e');
      return _getDemoTournaments();
    }
  }

  @override
  Future<TournamentModel> getTournamentById(String tournamentId) async {
    if (tournamentId.startsWith('demo_')) {
      final demoList = _getDemoTournaments();
      return demoList.firstWhere(
        (t) => t.id == tournamentId,
        orElse: () => demoList.first,
      );
    }
    try {
      final response = await _client.from('tournaments').select('*, cities:city_id(*), lounges:lounge_id(*)').eq('id', tournamentId).single();
      return TournamentModel.fromJson(response);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error in getTournamentById: $e, using demo fallback...');
      final demoList = _getDemoTournaments();
      return demoList.firstWhere(
        (t) => t.id == tournamentId,
        orElse: () => demoList.first,
      );
    }
  }

  @override
  Future<List<TournamentPrizeModel>> getTournamentPrizes(String tournamentId) async {
    if (tournamentId.startsWith('demo_')) {
      return _getDemoPrizes(tournamentId);
    }
    try {
      final response = await _client
          .from('tournament_prizes')
          .select()
          .eq('tournament_id', tournamentId)
          .order('placement', ascending: true);

      final list = (response as List).cast<Map<String, dynamic>>();
      final prizes = list.map((json) => TournamentPrizeModel.fromJson(json)).toList();
      if (prizes.isNotEmpty) return prizes;
      return _getDemoPrizes(tournamentId);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error fetching prizes: $e');
      return _getDemoPrizes(tournamentId);
    }
  }

  @override
  Future<List<TournamentMatchModel>> getTournamentMatches(String tournamentId) async {
    if (tournamentId.startsWith('demo_')) {
      return _getDemoMatches(tournamentId);
    }
    try {
      final response = await _client
          .from('tournament_matches')
          .select()
          .eq('tournament_id', tournamentId)
          .order('round_number', ascending: true)
          .order('match_order', ascending: true);

      final list = (response as List).cast<Map<String, dynamic>>();
      final matches = list.map((json) => TournamentMatchModel.fromJson(json)).toList();
      if (matches.isNotEmpty) return matches;
      return _getDemoMatches(tournamentId);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error in getTournamentMatches: $e');
      return _getDemoMatches(tournamentId);
    }
  }

  @override
  Future<TournamentMatchModel?> getMatchById(String tournamentId, String matchId) async {
    if (tournamentId.startsWith('demo_')) {
      final demoMatches = _getDemoMatches(tournamentId);
      final safeMatches = List<TournamentMatchModel>.from(demoMatches);
      return safeMatches.firstWhere(
        (m) => m.id == matchId,
        orElse: () => safeMatches.first,
      );
    }
    try {
      final response = await _client
          .from('tournament_matches')
          .select()
          .eq('id', matchId)
          .maybeSingle();

      if (response != null) {
        return TournamentMatchModel.fromJson(response);
      }
      final demoMatches = _getDemoMatches(tournamentId);
      if (demoMatches.isEmpty) return null;
      final safeMatches = List<TournamentMatchModel>.from(demoMatches);
      return safeMatches.firstWhere(
        (m) => m.id == matchId,
        orElse: () => safeMatches.first,
      );
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error in getMatchById: $e');
      final demoMatches = _getDemoMatches(tournamentId);
      if (demoMatches.isEmpty) return null;
      final safeMatches = List<TournamentMatchModel>.from(demoMatches);
      return safeMatches.firstWhere(
        (m) => m.id == matchId,
        orElse: () => safeMatches.first,
      );
    }
  }

  @override
  Future<TournamentParticipantModel?> getUserParticipant(
    String tournamentId,
    String userId,
  ) async {
    if (tournamentId.startsWith('demo_')) {
      return _getDemoParticipant(tournamentId, userId);
    }
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
      return _getDemoParticipant(tournamentId, userId);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error fetching user participant: $e');
      return _getDemoParticipant(tournamentId, userId);
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
          .maybeSingle();

      if (response == null) return null;
      return UserTournamentParticipationModel.fromJson(response);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error in getMyActiveTournament: $e');
      return null;
    }
  }

  @override
  Future<TournamentParticipantModel?> registerForTournament(String tournamentId) async {
    if (tournamentId.startsWith('demo_')) {
      _demoParticipantStatuses[tournamentId] = ParticipantStatus.confirmed;
      return _getDemoParticipant(tournamentId, 'demo_user');
    }

    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not logged in');
    }

    try {
      final res = await _client.rpc(
        'register_for_tournament',
        params: {
          'p_tournament_id': tournamentId,
        },
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
    if (participantId.startsWith('p_demo') || tournamentId.startsWith('demo_')) {
      _demoParticipantStatuses[tournamentId] = ParticipantStatus.pendingPayment;
      return _getDemoParticipant(tournamentId, userId);
    }

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
  Future<TournamentParticipantModel?> checkInParticipant(String participantId) async {
    if (participantId.startsWith('p_demo')) {
      _demoParticipantStatuses.forEach((key, value) {
        _demoParticipantStatuses[key] = ParticipantStatus.checkedIn;
      });
      return _getDemoParticipant('demo_fc24', 'demo_user');
    }

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
      dev.log('[TOURNAMENTS_REMOTE] RPC check_in_tournament_participant error: $e');
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
        params: {
          'p_match_id': matchId,
          'p_dispute_reason': disputeReason,
        },
      );
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC dispute_match_result error: $e');
      rethrow;
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
  Future<PaginatedResponse<Map<String, dynamic>>> getTournamentAuditLogsPage({
    required String tournamentId,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await _client.rpc('get_tournament_audit_logs_page', params: {
        'p_tournament_id': tournamentId,
        'p_page': page,
        'p_page_size': pageSize,
      });

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
      await _client.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', currentUser.id);
    } catch (e) {
      // Silent error for FCM token update
    }
  }

  final Map<String, ParticipantStatus> _demoParticipantStatuses = {};

  @override
  @override
  Future<TournamentParticipantModel?> withdrawFromTournament(String participantId, {String? tournamentId}) async {
    if (participantId.startsWith('p_demo') || (tournamentId != null && tournamentId.startsWith('demo_'))) {
      dev.log('[TOURNAMENTS_REMOTE] Withdraw demo tournament $tournamentId for participant $participantId');
      if (tournamentId != null) {
        _demoParticipantStatuses[tournamentId] = ParticipantStatus.withdrawn;
      } else {
        _demoParticipantStatuses['demo_fc24'] = ParticipantStatus.withdrawn;
      }
      return _getDemoParticipant(tournamentId ?? 'demo_fc24', 'demo_user');
    }
    try {
      final res = await _client.rpc(
        'withdraw_from_tournament',
        params: {
          'p_participant_id': participantId,
          'p_tournament_id': tournamentId,
        },
      );

      if (res is Map<String, dynamic>) {
        return TournamentParticipantModel.fromJson(res);
      }
      return null;
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC withdraw_from_tournament error, fallback to direct update: $e');
      final res = await _client.from('tournament_participants').update({
        'registration_status': 'withdrawn',
      }).eq('id', participantId).select().maybeSingle();

      if (res != null) {
        return TournamentParticipantModel.fromJson(res);
      }
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getUserTournamentHistory(String userId) async {
    try {
      final response = await _client
          .from('tournament_participants')
          .select('*, tournaments(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = (response as List).cast<Map<String, dynamic>>();
      if (list.isNotEmpty) return list;
      return _getDemoHistory(userId);
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] Error fetching user tournament history: $e');
      return _getDemoHistory(userId);
    }
  }

  @override
  Future<TournamentModel?> getHomeTournament() async {
    try {
      final response = await _client.rpc('get_home_tournament');
      if (response == null) return _getDemoTournaments().first;
      if (response is List) {
        if (response.isEmpty) return _getDemoTournaments().first;
        return TournamentModel.fromJson((response.first as Map).cast<String, dynamic>());
      }
      if (response is Map) {
        return TournamentModel.fromJson(response.cast<String, dynamic>());
      }
      return _getDemoTournaments().first;
    } catch (e) {
      dev.log('[TOURNAMENTS_REMOTE] RPC get_home_tournament error: $e');
      return _getDemoTournaments().first;
    }
  }

  List<TournamentModel> _getDemoTournaments() {
    final now = DateTime.now();
    return [
      TournamentModel(
        id: 'demo_fc24',
        title: 'بطولة EA FC 24 الأسبوعية',
        titleAr: 'بطولة EA FC 24 الأسبوعية',
        titleEn: 'EA FC 24 Weekly Cup',
        description: 'بطولة حماسية لأفضل لاعبي بلايستيشن في المنصورة. التحدي على جوائز كاش ونقاط ولاء.',
        descriptionAr: 'بطولة حماسية لأفضل لاعبي بلايستيشن في المنصورة. التحدي على جوائز كاش ونقاط ولاء.',
        descriptionEn: 'Exciting FC 24 tournament for PlayStation gamers in Mansoura with cash prizes and loyalty points.',
        game: 'FC 24',
        cityId: '1',
        cityName: 'المنصورة',
        loungeId: 'bdc97209-63fa-4693-9ced-80f9c08f8e12',
        loungeName: 'Sybar Gaming Lounge',
        bannerUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80',
        imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80',
        status: TournamentStatus.registrationOpen,
        maxParticipants: 16,
        registeredParticipantsCount: 12,
        bracketSize: 16,
        entryFee: 50.0,
        rulesAr: '1. نظام خروج المغلوب.\n2. مدة الشوط 6 دقائق.\n3. السرعة عادية والكاميرا الكلاسيكية.\n4. يمنع اختيار الفرق الخارقة (All-Stars).',
        rulesEn: '1. Single elimination knockout.\n2. Half length 6 minutes.\n3. Normal speed, Tactical camera.\n4. All-Star teams forbidden.',
        startDate: now.add(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 2, hours: 5)),
        registrationOpensAt: now.subtract(const Duration(days: 3)),
        registrationClosesAt: now.add(const Duration(days: 1)),
        checkInOpensAt: now.add(const Duration(days: 2, minutes: -60)),
        checkInClosesAt: now.add(const Duration(days: 2, minutes: -10)),
        checkInDeadline: now.add(const Duration(days: 2, minutes: -10)),
        allowWaitlist: true,
        currency: 'EGP',
      ),
      TournamentModel(
        id: 'demo_tekken8',
        title: 'بطولة Tekken 8 الكبرى',
        titleAr: 'بطولة Tekken 8 الكبرى',
        titleEn: 'Tekken 8 Ultimate Showdown',
        description: 'تحدي القتال الأقوى في الصالة، مواجهات حماسية 1v1 بنظام Best of 3.',
        descriptionAr: 'تحدي القتال الأقوى في الصالة، مواجهات حماسية 1v1 بنظام Best of 3.',
        descriptionEn: 'The ultimate fighting tournament, intense 1v1 matches in Best of 3 format.',
        game: 'Tekken 8',
        cityId: '1',
        cityName: 'المنصورة',
        loungeId: 'bdc97209-63fa-4693-9ced-80f9c08f8e12',
        loungeName: 'Sybar Gaming Lounge',
        bannerUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80',
        imageUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80',
        status: TournamentStatus.inProgress,
        maxParticipants: 8,
        registeredParticipantsCount: 8,
        bracketSize: 8,
        entryFee: 75.0,
        rulesAr: '1. نظام Best of 3.\n2. الجولات 3 جولات لكل ماكينة.\n3. اختيار المرحلة العشوائي.',
        rulesEn: '1. Best of 3 matches.\n2. 3 rounds per game.\n3. Random stage select.',
        startDate: now.subtract(const Duration(hours: 1)),
        endDate: now.add(const Duration(hours: 3)),
        allowWaitlist: false,
        currency: 'EGP',
      ),
      TournamentModel(
        id: 'demo_valorant',
        title: 'دوري Valorant الأبطال',
        titleAr: 'دوري Valorant الأبطال',
        titleEn: 'Valorant Masters Cyber League',
        description: 'بطولة الفرق لخمسة ضد خمسة على سيرفرات سريعة وشاشات 240Hz.',
        descriptionAr: 'بطولة الفرق لخمسة ضد خمسة على سيرفرات سريعة وشاشات 240Hz.',
        descriptionEn: '5v5 team tournament on high refresh rate PCs.',
        game: 'Valorant',
        cityId: '1',
        cityName: 'المنصورة',
        loungeId: 'bdc97209-63fa-4693-9ced-80f9c08f8e12',
        loungeName: 'Sybar Gaming Lounge',
        bannerUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1200&q=80',
        imageUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1200&q=80',
        status: TournamentStatus.published,
        maxParticipants: 16,
        registeredParticipantsCount: 14,
        bracketSize: 16,
        entryFee: 150.0,
        rulesAr: '1. نظام خروج المغلوب المزدوج Double Elimination.',
        rulesEn: '1. Double elimination bracket.',
        startDate: now.add(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 5, hours: 6)),
        allowWaitlist: true,
        currency: 'EGP',
      ),
    ];
  }

  List<TournamentPrizeModel> _getDemoPrizes(String tournamentId) {
    return const [
      TournamentPrizeModel(
        id: 'p1',
        tournamentId: 'demo',
        placement: 1,
        title: 'المركز الأول',
        prizeTitleAr: 'المركز الأول',
        prizeTitleEn: '1st Place',
        prizeType: PrizeType.cash,
        amount: 2500.0,
        cashAmount: 2500.0,
        points: 500,
        description: '2500 جنيه كاش + 500 نقطة ولاء + درع البطولة',
      ),
      TournamentPrizeModel(
        id: 'p2',
        tournamentId: 'demo',
        placement: 2,
        title: 'المركز الثاني',
        prizeTitleAr: 'المركز الثاني',
        prizeTitleEn: '2nd Place',
        prizeType: PrizeType.cash,
        amount: 1200.0,
        cashAmount: 1200.0,
        points: 250,
        description: '1200 جنيه كاش + 250 نقطة ولاء',
      ),
      TournamentPrizeModel(
        id: 'p3',
        tournamentId: 'demo',
        placement: 3,
        title: 'المركز الثالث',
        prizeTitleAr: 'المركز الثالث',
        prizeTitleEn: '3rd Place',
        prizeType: PrizeType.cash,
        amount: 500.0,
        cashAmount: 500.0,
        points: 100,
        description: '500 جنيه كاش + 100 نقطة ولاء',
      ),
    ];
  }

  List<TournamentMatchModel> _getDemoMatches(String tournamentId) {
    final now = DateTime.now();
    return [
      TournamentMatchModel(
        id: 'm1',
        tournamentId: tournamentId,
        roundNumber: 1,
        matchOrder: 1,
        player1Id: 'u1',
        player1Name: 'أحمد علي (ProGamer)',
        player1Score: 2,
        player2Id: 'u2',
        player2Name: 'عمر خالد (SniperX)',
        player2Score: 1,
        winnerId: 'u1',
        status: MatchStatus.completed,
        stationNumber: 'الجهاز 1',
        startedAt: now.subtract(const Duration(minutes: 40)),
        completedAt: now.subtract(const Duration(minutes: 10)),
      ),
      TournamentMatchModel(
        id: 'm2',
        tournamentId: tournamentId,
        roundNumber: 1,
        matchOrder: 2,
        player1Id: 'u3',
        player1Name: 'محمد صلاح (King_07)',
        player1Score: 3,
        player2Id: 'u4',
        player2Name: 'كريم محمود (DarkKnight)',
        player2Score: 0,
        winnerId: 'u3',
        status: MatchStatus.completed,
        stationNumber: 'الجهاز 2',
        startedAt: now.subtract(const Duration(minutes: 30)),
        completedAt: now.subtract(const Duration(minutes: 5)),
      ),
      TournamentMatchModel(
        id: 'm3',
        tournamentId: tournamentId,
        roundNumber: 1,
        matchOrder: 3,
        player1Id: 'u5',
        player1Name: 'محمود حسن (Shadow)',
        player1Score: 1,
        player2Id: 'u6',
        player2Name: 'يوسف أحمد (Viper)',
        player2Score: 2,
        winnerId: 'u6',
        status: MatchStatus.completed,
        stationNumber: 'الجهاز 3',
      ),
      TournamentMatchModel(
        id: 'm4',
        tournamentId: tournamentId,
        roundNumber: 1,
        matchOrder: 4,
        player1Id: 'u7',
        player1Name: 'سارة إبراهيم (Queen_PS)',
        player1Score: 2,
        player2Id: 'u8',
        player2Name: 'طارق زكي (Master99)',
        player2Score: 0,
        winnerId: 'u7',
        status: MatchStatus.completed,
        stationNumber: 'الجهاز 4',
      ),
      TournamentMatchModel(
        id: 'm5',
        tournamentId: tournamentId,
        roundNumber: 2,
        matchOrder: 1,
        player1Id: 'u1',
        player1Name: 'أحمد علي (ProGamer)',
        player1Score: 1,
        player2Id: 'u3',
        player2Name: 'محمد صلاح (King_07)',
        player2Score: 1,
        status: MatchStatus.inProgress,
        stationNumber: 'جهاز الـ VIP 1',
        startedAt: now.subtract(const Duration(minutes: 15)),
      ),
      TournamentMatchModel(
        id: 'm6',
        tournamentId: tournamentId,
        roundNumber: 2,
        matchOrder: 2,
        player1Id: 'u6',
        player1Name: 'يوسف أحمد (Viper)',
        player1Score: 0,
        player2Id: 'u7',
        player2Name: 'سارة إبراهيم (Queen_PS)',
        player2Score: 0,
        status: MatchStatus.scheduled,
        stationNumber: 'جهاز الـ VIP 2',
        scheduledAt: now.add(const Duration(minutes: 20)),
      ),
      TournamentMatchModel(
        id: 'm7',
        tournamentId: tournamentId,
        roundNumber: 3,
        matchOrder: 1,
        player1Name: 'فائز شبه النهائي 1',
        player2Name: 'فائز شبه النهائي 2',
        status: MatchStatus.scheduled,
        stationNumber: 'الشاشة الرئيسية',
        scheduledAt: now.add(const Duration(minutes: 60)),
      ),
    ];
  }

  TournamentParticipantModel _getDemoParticipant(String tournamentId, String userId) {
    final status = _demoParticipantStatuses[tournamentId] ?? ParticipantStatus.checkedIn;
    return TournamentParticipantModel(
      id: 'p_demo',
      tournamentId: tournamentId,
      userId: userId,
      userName: 'أنت (المستخدم الحالي)',
      status: status,
      paymentStatus: PaymentStatus.approved,
      checkedIn: status == ParticipantStatus.checkedIn,
      checkedInAt: status == ParticipantStatus.checkedIn ? DateTime.now().subtract(const Duration(minutes: 30)) : null,
    );
  }

  List<Map<String, dynamic>> _getDemoHistory(String userId) {
    return [
      {
        'id': 'p_history_1',
        'tournament_id': 'demo_fc24',
        'user_id': userId,
        'registration_status': 'confirmed',
        'payment_status': 'approved',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'tournaments': {
          'id': 'demo_fc24',
          'title': 'بطولة EA FC 24 الأسبوعية',
          'game_name': 'FC 24',
          'status': 'registration_open',
          'entry_fee': 50,
          'max_participants': 16,
          'registered_participants_count': 12,
        }
      },
      {
        'id': 'p_history_2',
        'tournament_id': 'demo_tekken8',
        'user_id': userId,
        'registration_status': 'confirmed',
        'payment_status': 'approved',
        'created_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        'tournaments': {
          'id': 'demo_tekken8',
          'title': 'بطولة Tekken 8 الكبرى',
          'game_name': 'Tekken 8',
          'status': 'completed',
          'entry_fee': 75,
          'max_participants': 8,
          'registered_participants_count': 8,
        }
      }
    ];
  }
}
