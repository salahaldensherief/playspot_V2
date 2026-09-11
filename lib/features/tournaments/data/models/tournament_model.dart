import '../../domain/entities/tournament_entity.dart';

class TournamentModel extends TournamentEntity {
  const TournamentModel({
    required super.id,
    required super.title,
    super.titleAr,
    super.titleEn,
    super.description,
    super.descriptionAr,
    super.descriptionEn,
    required super.game,
    super.cityId,
    super.cityName,
    super.loungeId,
    super.loungeName,
    super.imageUrl,
    super.bannerUrl,
    super.thumbnailUrl,
    required super.status,
    required super.maxParticipants,
    required super.registeredParticipantsCount,
    required super.bracketSize,
    required super.entryFee,
    super.rules,
    super.rulesAr,
    super.rulesEn,
    super.startDate,
    super.endDate,
    super.registrationOpensAt,
    super.registrationClosesAt,
    super.paymentDeadlineMinutes,
    super.checkInOpensAt,
    super.checkInClosesAt,
    super.checkInDeadline,
    super.championParticipantId,
    super.allowWaitlist,
    super.currency,
    super.createdAt,
    super.updatedAt,
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

    final String titleAr = json['title_ar']?.toString() ?? '';
    final String titleEn = json['title_en']?.toString() ?? '';
    final String parsedTitle = (titleEn.trim().isNotEmpty)
        ? titleEn
        : (titleAr.trim().isNotEmpty)
            ? titleAr
            : (json['title']?.toString().trim().isNotEmpty == true)
                ? json['title'].toString()
                : (json['name']?.toString().trim().isNotEmpty == true)
                    ? json['name'].toString()
                    : (json['game']?.toString().trim().isNotEmpty == true || json['game_name']?.toString().trim().isNotEmpty == true)
                        ? '${json['game'] ?? json['game_name']} Championship'
                        : 'PlaySpot Tournament';

    return TournamentModel(
      id: json['id']?.toString() ?? '',
      title: parsedTitle,
      titleAr: titleAr.isNotEmpty ? titleAr : null,
      titleEn: titleEn.isNotEmpty ? titleEn : null,
      description: json['description']?.toString(),
      descriptionAr: json['description_ar']?.toString(),
      descriptionEn: json['description_en']?.toString(),
      game: json['game_name']?.toString() ?? json['game']?.toString() ?? json['game_title']?.toString() ?? 'PlayStation',
      cityId: json['city_id']?.toString(),
      cityName: cityData?['name']?.toString() ?? json['city_name']?.toString(),
      loungeId: json['lounge_id']?.toString(),
      loungeName: loungeData?['name']?.toString() ?? json['lounge_name']?.toString(),
      imageUrl: json['banner_url']?.toString() ?? json['image_url']?.toString() ?? json['cover_image']?.toString(),
      bannerUrl: json['banner_url']?.toString() ?? json['image_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      status: TournamentStatus.fromString(json['status']?.toString()),
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 16,
      registeredParticipantsCount: registeredCount,
      bracketSize: (json['bracket_size'] as num?)?.toInt() ?? (json['max_participants'] as num?)?.toInt() ?? 16,
      entryFee: (json['entry_fee'] as num?)?.toDouble() ?? 0.0,
      rules: json['rules']?.toString() ?? json['rules_ar']?.toString() ?? json['rules_en']?.toString(),
      rulesAr: json['rules_ar']?.toString(),
      rulesEn: json['rules_en']?.toString(),
      startDate: json['tournament_starts_at'] != null
          ? DateTime.tryParse(json['tournament_starts_at'].toString())
          : json['start_date'] != null
              ? DateTime.tryParse(json['start_date'].toString())
              : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) : null,
      registrationOpensAt: json['registration_opens_at'] != null
          ? DateTime.tryParse(json['registration_opens_at'].toString())
          : null,
      registrationClosesAt: json['registration_closes_at'] != null
          ? DateTime.tryParse(json['registration_closes_at'].toString())
          : null,
      paymentDeadlineMinutes: (json['payment_deadline_minutes'] as num?)?.toInt(),
      checkInOpensAt: json['check_in_opens_at'] != null
          ? DateTime.tryParse(json['check_in_opens_at'].toString())
          : null,
      checkInClosesAt: json['check_in_closes_at'] != null
          ? DateTime.tryParse(json['check_in_closes_at'].toString())
          : null,
      checkInDeadline: json['check_in_closes_at'] != null
          ? DateTime.tryParse(json['check_in_closes_at'].toString())
          : json['check_in_deadline'] != null
              ? DateTime.tryParse(json['check_in_deadline'].toString())
              : null,
      championParticipantId: json['champion_participant_id']?.toString(),
      allowWaitlist: json['allow_waitlist'] != false,
      currency: json['currency']?.toString() ?? 'EGP',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'title_ar': titleAr,
      'title_en': titleEn,
      'description': description,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'game_name': game,
      'city_id': cityId,
      'lounge_id': loungeId,
      'banner_url': bannerUrl,
      'thumbnail_url': thumbnailUrl,
      'status': status.toDbString(),
      'max_participants': maxParticipants,
      'bracket_size': bracketSize,
      'entry_fee': entryFee,
      'rules': rules,
      'rules_ar': rulesAr,
      'rules_en': rulesEn,
      'tournament_starts_at': startDate?.toIso8601String(),
      'registration_opens_at': registrationOpensAt?.toIso8601String(),
      'registration_closes_at': registrationClosesAt?.toIso8601String(),
      'payment_deadline_minutes': paymentDeadlineMinutes,
      'check_in_opens_at': checkInOpensAt?.toIso8601String(),
      'check_in_closes_at': checkInClosesAt?.toIso8601String(),
      'allow_waitlist': allowWaitlist,
      'currency': currency,
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
    super.paymentDeadline,
    super.approvedBy,
    super.approvedAt,
    super.paymentRejectionReason,
    required super.checkedIn,
    super.checkedInAt,
    super.waitlistPosition,
    super.cashReceivedBy,
    super.cashReceivedAt,
    super.cashReferenceNote,
    super.createdAt,
  });

  factory TournamentParticipantModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? profileData;
    if (json['profiles'] is Map<String, dynamic>) {
      profileData = json['profiles'] as Map<String, dynamic>;
    }

    final bool isCheckedIn = json['is_checked_in'] == true ||
        json['checked_in'] == true ||
        json['registration_status'] == 'checked_in';

    return TournamentParticipantModel(
      id: json['id']?.toString() ?? '',
      tournamentId: json['tournament_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: profileData?['full_name']?.toString() ?? json['user_name']?.toString(),
      userAvatarUrl: profileData?['avatar_url']?.toString() ?? json['user_avatar']?.toString(),
      status: ParticipantStatus.fromString(json['registration_status']?.toString() ?? json['status']?.toString()),
      paymentStatus: PaymentStatus.fromString(json['payment_status']?.toString()),
      paymentMethod: json['payment_method']?.toString(),
      receiptUrl: json['receipt_url']?.toString(),
      paymentDeadline: json['payment_deadline'] != null ? DateTime.tryParse(json['payment_deadline'].toString()) : null,
      approvedBy: json['approved_by']?.toString(),
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
      paymentRejectionReason: json['payment_rejection_reason']?.toString(),
      checkedIn: isCheckedIn,
      checkedInAt: json['checked_in_at'] != null ? DateTime.tryParse(json['checked_in_at'].toString()) : null,
      waitlistPosition: (json['waitlist_position'] as num?)?.toInt(),
      cashReceivedBy: json['cash_received_by']?.toString(),
      cashReceivedAt: json['cash_received_at'] != null ? DateTime.tryParse(json['cash_received_at'].toString()) : null,
      cashReferenceNote: json['cash_reference_note']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tournament_id': tournamentId,
      'user_id': userId,
      'registration_status': status.toDbString(),
      'payment_status': paymentStatus.toDbString(),
      'payment_method': paymentMethod,
      'receipt_url': receiptUrl,
      'payment_deadline': paymentDeadline?.toIso8601String(),
      'is_checked_in': checkedIn,
      'checked_in_at': checkedInAt?.toIso8601String(),
      'waitlist_position': waitlistPosition,
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
    super.scheduledAt,
    super.scheduledEndAt,
    super.startedAt,
    super.completedAt,
    required super.status,
    super.proofUrl,
    super.submittedBy,
    super.resultSubmittedAt,
    super.confirmationDeadline,
    super.disputeReason,
    super.disputedBy,
    super.disputedAt,
    super.resolvedBy,
    super.resolvedAt,
    super.resolutionNotes,
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
      player1Score: (json['score_player1'] as num?)?.toInt() ?? (json['player1_score'] as num?)?.toInt(),
      player2Id: json['player2_id']?.toString(),
      player2Name: p2Data?['full_name']?.toString() ?? json['player2_name']?.toString(),
      player2Avatar: p2Data?['avatar_url']?.toString() ?? json['player2_avatar']?.toString(),
      player2Score: (json['score_player2'] as num?)?.toInt() ?? (json['player2_score'] as num?)?.toInt(),
      winnerId: json['winner_id']?.toString(),
      nextMatchId: json['next_match_id']?.toString(),
      nextMatchSlot: (json['next_match_slot'] as num?)?.toInt(),
      roomId: json['room_id']?.toString(),
      stationNumber: json['station_number']?.toString() ?? json['room_number']?.toString(),
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse(json['scheduled_at'].toString()) : null,
      scheduledEndAt: json['scheduled_end_at'] != null ? DateTime.tryParse(json['scheduled_end_at'].toString()) : null,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      status: MatchStatus.fromString(json['status']?.toString()),
      proofUrl: json['proof_image_url']?.toString() ?? json['proof_url']?.toString(),
      submittedBy: json['submitted_by']?.toString(),
      resultSubmittedAt: json['result_submitted_at'] != null ? DateTime.tryParse(json['result_submitted_at'].toString()) : null,
      confirmationDeadline: json['confirmation_deadline'] != null
          ? DateTime.tryParse(json['confirmation_deadline'].toString())
          : null,
      disputeReason: json['dispute_reason']?.toString(),
      disputedBy: json['disputed_by']?.toString(),
      disputedAt: json['disputed_at'] != null ? DateTime.tryParse(json['disputed_at'].toString()) : null,
      resolvedBy: json['resolved_by']?.toString(),
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null,
      resolutionNotes: json['resolution_notes']?.toString(),
    );
  }
}

class TournamentPrizeModel extends TournamentPrizeEntity {
  const TournamentPrizeModel({
    required super.id,
    required super.tournamentId,
    required super.placement,
    required super.title,
    super.prizeTitleAr,
    super.prizeTitleEn,
    super.prizeType,
    required super.amount,
    super.cashAmount,
    super.points,
    super.bonus,
    super.productName,
    super.description,
    super.metadata,
  });

  factory TournamentPrizeModel.fromJson(Map<String, dynamic> json) {
    final double cashVal = (json['cash_amount'] as num?)?.toDouble() ?? 0.0;
    final double bonusVal = (json['bonus'] as num?)?.toDouble() ?? 0.0;
    final int pointsVal = (json['points'] as num?)?.toInt() ?? 0;
    final double totalAmount = (json['amount'] as num?)?.toDouble() ?? (cashVal > 0 ? cashVal : bonusVal);

    return TournamentPrizeModel(
      id: json['id']?.toString() ?? '',
      tournamentId: json['tournament_id']?.toString() ?? '',
      placement: (json['placement'] as num?)?.toInt() ?? 1,
      title: json['prize_title_ar']?.toString() ??
          json['prize_title_en']?.toString() ??
          json['title']?.toString() ??
          json['name']?.toString() ??
          'Prize',
      prizeTitleAr: json['prize_title_ar']?.toString(),
      prizeTitleEn: json['prize_title_en']?.toString(),
      prizeType: PrizeType.fromString(json['prize_type']?.toString()),
      amount: totalAmount,
      cashAmount: cashVal,
      points: pointsVal,
      bonus: bonusVal,
      productName: json['product_name']?.toString(),
      description: json['description']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : null,
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
      pointsEarned: (json['points_earned'] as num?)?.toInt() ?? (json['points'] as num?)?.toInt(),
      prizeAmount: (json['prize_amount'] as num?)?.toDouble() ?? (json['amount'] as num?)?.toDouble(),
    );
  }
}
