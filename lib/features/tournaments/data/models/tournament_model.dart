import '../../domain/entities/tournament_entity.dart';

class TournamentModel extends TournamentEntity {
  const TournamentModel({
    required super.id,
    required super.title,
    super.description,
    required super.game,
    super.cityId,
    super.cityName,
    super.loungeId,
    super.loungeName,
    super.imageUrl,
    required super.status,
    required super.maxParticipants,
    required super.registeredParticipantsCount,
    required super.bracketSize,
    required super.entryFee,
    super.rules,
    super.startDate,
    super.endDate,
    super.checkInDeadline,
    super.createdAt,
  });

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? cityData;
    if (json['cities'] is Map<String, dynamic>) {
      cityData = json['cities'] as Map<String, dynamic>;
    }

    Map<String, dynamic>? loungeData;
    if (json['lounges'] is Map<String, dynamic>) {
      loungeData = json['lounges'] as Map<String, dynamic>;
    }

    int registeredCount = 0;
    if (json['tournament_participants'] is List) {
      registeredCount = (json['tournament_participants'] as List).length;
    } else if (json['registered_participants_count'] != null) {
      registeredCount = (json['registered_participants_count'] as num).toInt();
    } else if (json['registered_count'] != null) {
      registeredCount = (json['registered_count'] as num).toInt();
    }

    final String parsedTitle = (json['title']?.toString().trim().isNotEmpty == true)
        ? json['title'].toString()
        : (json['name']?.toString().trim().isNotEmpty == true)
            ? json['name'].toString()
            : (json['game']?.toString().trim().isNotEmpty == true)
                ? '${json['game']} Championship'
                : 'PlaySpot Tournament';

    return TournamentModel(
      id: json['id']?.toString() ?? '',
      title: parsedTitle,
      description: json['description']?.toString(),
      game: json['game']?.toString() ?? json['game_title']?.toString() ?? 'PlayStation',
      cityId: json['city_id']?.toString(),
      cityName: cityData?['name']?.toString() ?? json['city_name']?.toString(),
      loungeId: json['lounge_id']?.toString(),
      loungeName: loungeData?['name']?.toString() ?? json['lounge_name']?.toString(),
      imageUrl: json['image_url']?.toString() ?? json['cover_image']?.toString(),
      status: TournamentStatus.fromString(json['status']?.toString()),
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 16,
      registeredParticipantsCount: registeredCount,
      bracketSize: (json['bracket_size'] as num?)?.toInt() ?? (json['max_participants'] as num?)?.toInt() ?? 16,
      entryFee: (json['entry_fee'] as num?)?.toDouble() ?? 0.0,
      rules: json['rules']?.toString(),
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) : null,
      checkInDeadline: json['check_in_deadline'] != null ? DateTime.tryParse(json['check_in_deadline'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'game': game,
      'city_id': cityId,
      'lounge_id': loungeId,
      'image_url': imageUrl,
      'status': status.toDbString(),
      'max_participants': maxParticipants,
      'bracket_size': bracketSize,
      'entry_fee': entryFee,
      'rules': rules,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'check_in_deadline': checkInDeadline?.toIso8601String(),
    };
  }
}

class TournamentParticipantModel extends TournamentParticipantEntity {
  const TournamentParticipantModel({
    required super.id,
    required super.tournamentId,
    required super.userId,
    super.userName,
    super.userAvatarUrl,
    required super.status,
    required super.paymentStatus,
    super.paymentMethod,
    super.receiptUrl,
    required super.checkedIn,
    super.checkedInAt,
    super.createdAt,
  });

  factory TournamentParticipantModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? profileData;
    if (json['profiles'] is Map<String, dynamic>) {
      profileData = json['profiles'] as Map<String, dynamic>;
    }

    return TournamentParticipantModel(
      id: json['id']?.toString() ?? '',
      tournamentId: json['tournament_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: profileData?['full_name']?.toString() ?? json['user_name']?.toString(),
      userAvatarUrl: profileData?['avatar_url']?.toString() ?? json['user_avatar']?.toString(),
      status: ParticipantStatus.fromString(json['status']?.toString()),
      paymentStatus: PaymentStatus.fromString(json['payment_status']?.toString()),
      paymentMethod: json['payment_method']?.toString(),
      receiptUrl: json['receipt_url']?.toString(),
      checkedIn: json['checked_in'] == true,
      checkedInAt: json['checked_in_at'] != null ? DateTime.tryParse(json['checked_in_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tournament_id': tournamentId,
      'user_id': userId,
      'status': status.toDbString(),
      'payment_status': paymentStatus.toDbString(),
      'payment_method': paymentMethod,
      'receipt_url': receiptUrl,
      'checked_in': checkedIn,
      'checked_in_at': checkedInAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class TournamentMatchModel extends TournamentMatchEntity {
  const TournamentMatchModel({
    required super.id,
    required super.tournamentId,
    required super.roundNumber,
    required super.matchOrder,
    super.player1Id,
    super.player1Name,
    super.player1Avatar,
    super.player1Score,
    super.player2Id,
    super.player2Name,
    super.player2Avatar,
    super.player2Score,
    super.winnerId,
    super.nextMatchId,
    super.nextMatchSlot,
    super.roomId,
    super.stationNumber,
    required super.status,
    super.proofUrl,
    super.submittedBy,
    super.confirmationDeadline,
    super.disputeReason,
  });

  factory TournamentMatchModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? p1Data;
    if (json['player1'] is Map<String, dynamic>) {
      p1Data = json['player1'] as Map<String, dynamic>;
    }

    Map<String, dynamic>? p2Data;
    if (json['player2'] is Map<String, dynamic>) {
      p2Data = json['player2'] as Map<String, dynamic>;
    }

    return TournamentMatchModel(
      id: json['id']?.toString() ?? '',
      tournamentId: json['tournament_id']?.toString() ?? '',
      roundNumber: (json['round_number'] as num?)?.toInt() ?? 1,
      matchOrder: (json['match_order'] as num?)?.toInt() ?? 1,
      player1Id: json['player1_id']?.toString(),
      player1Name: p1Data?['full_name']?.toString() ?? json['player1_name']?.toString(),
      player1Avatar: p1Data?['avatar_url']?.toString() ?? json['player1_avatar']?.toString(),
      player1Score: (json['player1_score'] as num?)?.toInt(),
      player2Id: json['player2_id']?.toString(),
      player2Name: p2Data?['full_name']?.toString() ?? json['player2_name']?.toString(),
      player2Avatar: p2Data?['avatar_url']?.toString() ?? json['player2_avatar']?.toString(),
      player2Score: (json['player2_score'] as num?)?.toInt(),
      winnerId: json['winner_id']?.toString(),
      nextMatchId: json['next_match_id']?.toString(),
      nextMatchSlot: (json['next_match_slot'] as num?)?.toInt(),
      roomId: json['room_id']?.toString(),
      stationNumber: json['station_number']?.toString() ?? json['room_number']?.toString(),
      status: MatchStatus.fromString(json['status']?.toString()),
      proofUrl: json['proof_url']?.toString(),
      submittedBy: json['submitted_by']?.toString(),
      confirmationDeadline: json['confirmation_deadline'] != null
          ? DateTime.tryParse(json['confirmation_deadline'].toString())
          : null,
      disputeReason: json['dispute_reason']?.toString(),
    );
  }
}

class TournamentPrizeModel extends TournamentPrizeEntity {
  const TournamentPrizeModel({
    required super.id,
    required super.tournamentId,
    required super.placement,
    required super.title,
    required super.rewardType,
    required super.amount,
    super.description,
  });

  factory TournamentPrizeModel.fromJson(Map<String, dynamic> json) {
    return TournamentPrizeModel(
      id: json['id']?.toString() ?? '',
      tournamentId: json['tournament_id']?.toString() ?? '',
      placement: (json['placement'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Prize',
      rewardType: json['reward_type']?.toString() ?? 'cash',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString(),
    );
  }
}

class TournamentPlacementModel extends TournamentPlacementEntity {
  const TournamentPlacementModel({
    required super.id,
    required super.tournamentId,
    required super.userId,
    super.userName,
    required super.rank,
    super.pointsEarned,
    super.prizeAmount,
  });

  factory TournamentPlacementModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? profileData;
    if (json['profiles'] is Map<String, dynamic>) {
      profileData = json['profiles'] as Map<String, dynamic>;
    }

    return TournamentPlacementModel(
      id: json['id']?.toString() ?? '',
      tournamentId: json['tournament_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: profileData?['full_name']?.toString() ?? json['user_name']?.toString(),
      rank: (json['rank'] as num?)?.toInt() ?? (json['placement'] as num?)?.toInt() ?? 1,
      pointsEarned: (json['points_earned'] as num?)?.toInt(),
      prizeAmount: (json['prize_amount'] as num?)?.toDouble(),
    );
  }
}
