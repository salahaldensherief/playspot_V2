import 'package:equatable/equatable.dart';

enum TournamentStatus {
  draft,
  published,
  registrationOpen,
  registrationClosed,
  checkInOpen,
  checkInClosed,
  drawCompleted,
  inProgress,
  completed,
  cancelled;

  String toDbString() {
    switch (this) {
      case TournamentStatus.draft:
        return 'draft';
      case TournamentStatus.published:
        return 'published';
      case TournamentStatus.registrationOpen:
        return 'registration_open';
      case TournamentStatus.registrationClosed:
        return 'registration_closed';
      case TournamentStatus.checkInOpen:
        return 'check_in_open';
      case TournamentStatus.checkInClosed:
        return 'check_in_closed';
      case TournamentStatus.drawCompleted:
        return 'draw_completed';
      case TournamentStatus.inProgress:
        return 'in_progress';
      case TournamentStatus.completed:
        return 'completed';
      case TournamentStatus.cancelled:
        return 'cancelled';
    }
  }

  static TournamentStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'draft':
        return TournamentStatus.draft;
      case 'published':
        return TournamentStatus.published;
      case 'registration_open':
        return TournamentStatus.registrationOpen;
      case 'registration_closed':
        return TournamentStatus.registrationClosed;
      case 'check_in_open':
        return TournamentStatus.checkInOpen;
      case 'check_in_closed':
        return TournamentStatus.checkInClosed;
      case 'draw_completed':
        return TournamentStatus.drawCompleted;
      case 'in_progress':
        return TournamentStatus.inProgress;
      case 'completed':
        return TournamentStatus.completed;
      case 'cancelled':
        return TournamentStatus.cancelled;
      default:
        return TournamentStatus.registrationOpen;
    }
  }
}

enum ParticipantStatus {
  pendingPayment,
  waitlist,
  confirmed,
  checkedIn,
  eliminated,
  expired,
  cancelled,
  withdrawn,
  noShow;

  String toDbString() {
    switch (this) {
      case ParticipantStatus.pendingPayment:
        return 'pending_payment';
      case ParticipantStatus.waitlist:
        return 'waitlist';
      case ParticipantStatus.confirmed:
        return 'confirmed';
      case ParticipantStatus.checkedIn:
        return 'checked_in';
      case ParticipantStatus.eliminated:
        return 'eliminated';
      case ParticipantStatus.expired:
        return 'expired';
      case ParticipantStatus.cancelled:
        return 'cancelled';
      case ParticipantStatus.withdrawn:
        return 'withdrawn';
      case ParticipantStatus.noShow:
        return 'no_show';
    }
  }

  static ParticipantStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'pending_payment':
        return ParticipantStatus.pendingPayment;
      case 'waitlist':
        return ParticipantStatus.waitlist;
      case 'confirmed':
        return ParticipantStatus.confirmed;
      case 'checked_in':
        return ParticipantStatus.checkedIn;
      case 'eliminated':
        return ParticipantStatus.eliminated;
      case 'expired':
        return ParticipantStatus.expired;
      case 'cancelled':
        return ParticipantStatus.cancelled;
      case 'withdrawn':
        return ParticipantStatus.withdrawn;
      case 'no_show':
        return ParticipantStatus.noShow;
      default:
        return ParticipantStatus.pendingPayment;
    }
  }
}

enum PaymentStatus {
  unpaid,
  pendingVerification,
  paid;

  String toDbString() {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.pendingVerification:
        return 'pending_verification';
      case PaymentStatus.paid:
        return 'paid';
    }
  }

  static PaymentStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'pending':
      case 'pending_verification':
        return PaymentStatus.pendingVerification;
      case 'unpaid':
      default:
        return PaymentStatus.unpaid;
    }
  }
}

enum MatchStatus {
  scheduled,
  inProgress,
  pendingConfirmation,
  disputed,
  completed,
  cancelled,
  walkover,
  noShow;

  String toDbString() {
    switch (this) {
      case MatchStatus.scheduled:
        return 'scheduled';
      case MatchStatus.inProgress:
        return 'in_progress';
      case MatchStatus.pendingConfirmation:
        return 'pending_confirmation';
      case MatchStatus.disputed:
        return 'disputed';
      case MatchStatus.completed:
        return 'completed';
      case MatchStatus.cancelled:
        return 'cancelled';
      case MatchStatus.walkover:
        return 'walkover';
      case MatchStatus.noShow:
        return 'no_show';
    }
  }

  static MatchStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'scheduled':
        return MatchStatus.scheduled;
      case 'in_progress':
        return MatchStatus.inProgress;
      case 'pending_confirmation':
        return MatchStatus.pendingConfirmation;
      case 'disputed':
        return MatchStatus.disputed;
      case 'completed':
        return MatchStatus.completed;
      case 'cancelled':
        return MatchStatus.cancelled;
      case 'walkover':
        return MatchStatus.walkover;
      case 'no_show':
        return MatchStatus.noShow;
      default:
        return MatchStatus.scheduled;
    }
  }
}

enum StationStatus {
  available,
  assigned,
  maintenance,
  disabled;

  String toDbString() {
    return name;
  }

  static StationStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'available':
        return StationStatus.available;
      case 'assigned':
        return StationStatus.assigned;
      case 'maintenance':
        return StationStatus.maintenance;
      case 'disabled':
        return StationStatus.disabled;
      default:
        return StationStatus.available;
    }
  }
}

enum PrizeType {
  cash,
  points,
  product,
  discount,
  freeBooking,
  other;

  String toDbString() {
    switch (this) {
      case PrizeType.cash:
        return 'cash';
      case PrizeType.points:
        return 'points';
      case PrizeType.product:
        return 'product';
      case PrizeType.discount:
        return 'discount';
      case PrizeType.freeBooking:
        return 'free_booking';
      case PrizeType.other:
        return 'other';
    }
  }

  static PrizeType fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'cash':
        return PrizeType.cash;
      case 'points':
        return PrizeType.points;
      case 'product':
        return PrizeType.product;
      case 'discount':
        return PrizeType.discount;
      case 'free_booking':
        return PrizeType.freeBooking;
      case 'other':
      default:
        return PrizeType.other;
    }
  }
}

class TournamentEntity extends Equatable {
  final String id;
  final String title;
  final String? titleAr;
  final String? titleEn;
  final String? description;
  final String? descriptionAr;
  final String? descriptionEn;
  final String game;
  final String? cityId;
  final String? cityName;
  final String? loungeId;
  final String? loungeName;
  final String? imageUrl;
  final String? bannerUrl;
  final String? thumbnailUrl;
  final TournamentStatus status;
  final int maxParticipants;
  final int registeredParticipantsCount;
  final int bracketSize;
  final double entryFee;
  final String? rules;
  final String? rulesAr;
  final String? rulesEn;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? registrationOpensAt;
  final DateTime? registrationClosesAt;
  final int? paymentDeadlineMinutes;
  final DateTime? checkInOpensAt;
  final DateTime? checkInClosesAt;
  final DateTime? checkInDeadline;
  final String? championParticipantId;
  final bool allowWaitlist;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TournamentEntity({
    required this.id,
    required this.title,
    this.titleAr,
    this.titleEn,
    this.description,
    this.descriptionAr,
    this.descriptionEn,
    required this.game,
    this.cityId,
    this.cityName,
    this.loungeId,
    this.loungeName,
    this.imageUrl,
    this.bannerUrl,
    this.thumbnailUrl,
    required this.status,
    required this.maxParticipants,
    required this.registeredParticipantsCount,
    required this.bracketSize,
    required this.entryFee,
    this.rules,
    this.rulesAr,
    this.rulesEn,
    this.startDate,
    this.endDate,
    this.registrationOpensAt,
    this.registrationClosesAt,
    this.paymentDeadlineMinutes,
    this.checkInOpensAt,
    this.checkInClosesAt,
    this.checkInDeadline,
    this.championParticipantId,
    this.allowWaitlist = true,
    this.currency = 'EGP',
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        titleAr,
        titleEn,
        description,
        descriptionAr,
        descriptionEn,
        game,
        cityId,
        cityName,
        loungeId,
        loungeName,
        imageUrl,
        bannerUrl,
        thumbnailUrl,
        status,
        maxParticipants,
        registeredParticipantsCount,
        bracketSize,
        entryFee,
        rules,
        rulesAr,
        rulesEn,
        startDate,
        endDate,
        registrationOpensAt,
        registrationClosesAt,
        paymentDeadlineMinutes,
        checkInOpensAt,
        checkInClosesAt,
        checkInDeadline,
        championParticipantId,
        allowWaitlist,
        currency,
        createdAt,
        updatedAt,
      ];
}

class TournamentParticipantEntity extends Equatable {
  final String id;
  final String tournamentId;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final ParticipantStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentMethod;
  final String? receiptUrl;
  final DateTime? paymentDeadline;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? paymentRejectionReason;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final int? waitlistPosition;
  final String? cashReceivedBy;
  final DateTime? cashReceivedAt;
  final String? cashReferenceNote;
  final DateTime? createdAt;

  const TournamentParticipantEntity({
    required this.id,
    required this.tournamentId,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod,
    this.receiptUrl,
    this.paymentDeadline,
    this.approvedBy,
    this.approvedAt,
    this.paymentRejectionReason,
    required this.checkedIn,
    this.checkedInAt,
    this.waitlistPosition,
    this.cashReceivedBy,
    this.cashReceivedAt,
    this.cashReferenceNote,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        tournamentId,
        userId,
        userName,
        userAvatarUrl,
        status,
        paymentStatus,
        paymentMethod,
        receiptUrl,
        paymentDeadline,
        approvedBy,
        approvedAt,
        paymentRejectionReason,
        checkedIn,
        checkedInAt,
        waitlistPosition,
        cashReceivedBy,
        cashReceivedAt,
        cashReferenceNote,
        createdAt,
      ];
}

class TournamentMatchEntity extends Equatable {
  final String id;
  final String tournamentId;
  final int roundNumber;
  final int matchOrder;
  final String? player1Id;
  final String? player1Name;
  final String? player1Avatar;
  final int? player1Score;
  final String? player2Id;
  final String? player2Name;
  final String? player2Avatar;
  final int? player2Score;
  final String? winnerId;
  final String? nextMatchId;
  final int? nextMatchSlot;
  final String? roomId;
  final String? stationNumber;
  final DateTime? scheduledAt;
  final DateTime? scheduledEndAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final MatchStatus status;
  final String? proofUrl;
  final String? submittedBy;
  final DateTime? resultSubmittedAt;
  final DateTime? confirmationDeadline;
  final String? disputeReason;
  final String? disputedBy;
  final DateTime? disputedAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

  const TournamentMatchEntity({
    required this.id,
    required this.tournamentId,
    required this.roundNumber,
    required this.matchOrder,
    this.player1Id,
    this.player1Name,
    this.player1Avatar,
    this.player1Score,
    this.player2Id,
    this.player2Name,
    this.player2Avatar,
    this.player2Score,
    this.winnerId,
    this.nextMatchId,
    this.nextMatchSlot,
    this.roomId,
    this.stationNumber,
    this.scheduledAt,
    this.scheduledEndAt,
    this.startedAt,
    this.completedAt,
    required this.status,
    this.proofUrl,
    this.submittedBy,
    this.resultSubmittedAt,
    this.confirmationDeadline,
    this.disputeReason,
    this.disputedBy,
    this.disputedAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNotes,
  });

  bool get isBye => player1Id == null || player2Id == null;

  @override
  List<Object?> get props => [
        id,
        tournamentId,
        roundNumber,
        matchOrder,
        player1Id,
        player1Name,
        player1Avatar,
        player1Score,
        player2Id,
        player2Name,
        player2Avatar,
        player2Score,
        winnerId,
        nextMatchId,
        nextMatchSlot,
        roomId,
        stationNumber,
        scheduledAt,
        scheduledEndAt,
        startedAt,
        completedAt,
        status,
        proofUrl,
        submittedBy,
        resultSubmittedAt,
        confirmationDeadline,
        disputeReason,
        disputedBy,
        disputedAt,
        resolvedBy,
        resolvedAt,
        resolutionNotes,
      ];
}

class TournamentPrizeEntity extends Equatable {
  final String id;
  final String tournamentId;
  final int placement;
  final String title;
  final String? prizeTitleAr;
  final String? prizeTitleEn;
  final PrizeType prizeType;
  final double amount;
  final double cashAmount;
  final int points;
  final double bonus;
  final String? productName;
  final String? description;
  final Map<String, dynamic>? metadata;

  const TournamentPrizeEntity({
    required this.id,
    required this.tournamentId,
    required this.placement,
    required this.title,
    this.prizeTitleAr,
    this.prizeTitleEn,
    this.prizeType = PrizeType.cash,
    required this.amount,
    this.cashAmount = 0.0,
    this.points = 0,
    this.bonus = 0.0,
    this.productName,
    this.description,
    this.metadata,
  });

  @override
  List<Object?> get props => [
        id,
        tournamentId,
        placement,
        title,
        prizeTitleAr,
        prizeTitleEn,
        prizeType,
        amount,
        cashAmount,
        points,
        bonus,
        productName,
        description,
        metadata,
      ];
}

class TournamentPlacementEntity extends Equatable {
  final String id;
  final String tournamentId;
  final String userId;
  final String? userName;
  final int rank;
  final int? pointsEarned;
  final double? prizeAmount;

  const TournamentPlacementEntity({
    required this.id,
    required this.tournamentId,
    required this.userId,
    this.userName,
    required this.rank,
    this.pointsEarned,
    this.prizeAmount,
  });

  @override
  List<Object?> get props => [
        id,
        tournamentId,
        userId,
        userName,
        rank,
        pointsEarned,
        prizeAmount,
      ];
}

