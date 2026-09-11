import 'package:equatable/equatable.dart';

enum TournamentStatus {
  registrationOpen,
  checkInOpen,
  inProgress,
  completed,
  cancelled;

  String toDbString() {
    switch (this) {
      case TournamentStatus.registrationOpen:
        return 'registration_open';
      case TournamentStatus.checkInOpen:
        return 'check_in_open';
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
      case 'registration_open':
        return TournamentStatus.registrationOpen;
      case 'check_in_open':
        return TournamentStatus.checkInOpen;
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
  confirmed,
  pendingPayment,
  waitlist,
  cancelled;

  String toDbString() {
    switch (this) {
      case ParticipantStatus.confirmed:
        return 'confirmed';
      case ParticipantStatus.pendingPayment:
        return 'pending_payment';
      case ParticipantStatus.waitlist:
        return 'waitlist';
      case ParticipantStatus.cancelled:
        return 'cancelled';
    }
  }

  static ParticipantStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'confirmed':
        return ParticipantStatus.confirmed;
      case 'pending_payment':
        return ParticipantStatus.pendingPayment;
      case 'waitlist':
        return ParticipantStatus.waitlist;
      case 'cancelled':
        return ParticipantStatus.cancelled;
      default:
        return ParticipantStatus.pendingPayment;
    }
  }
}

enum PaymentStatus {
  paid,
  unpaid,
  pendingVerification;

  String toDbString() {
    switch (this) {
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.pendingVerification:
        return 'pending_verification';
    }
  }

  static PaymentStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'unpaid':
        return PaymentStatus.unpaid;
      case 'pending_verification':
        return PaymentStatus.pendingVerification;
      default:
        return PaymentStatus.unpaid;
    }
  }
}

enum MatchStatus {
  scheduled,
  inProgress,
  pendingConfirmation,
  completed,
  disputed;

  String toDbString() {
    switch (this) {
      case MatchStatus.scheduled:
        return 'scheduled';
      case MatchStatus.inProgress:
        return 'in_progress';
      case MatchStatus.pendingConfirmation:
        return 'pending_confirmation';
      case MatchStatus.completed:
        return 'completed';
      case MatchStatus.disputed:
        return 'disputed';
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
      case 'completed':
        return MatchStatus.completed;
      case 'disputed':
        return MatchStatus.disputed;
      default:
        return MatchStatus.scheduled;
    }
  }
}

class TournamentEntity extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String game;
  final String? cityId;
  final String? cityName;
  final String? loungeId;
  final String? loungeName;
  final String? imageUrl;
  final TournamentStatus status;
  final int maxParticipants;
  final int registeredParticipantsCount;
  final int bracketSize;
  final double entryFee;
  final String? rules;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? checkInDeadline;
  final DateTime? createdAt;

  const TournamentEntity({
    required this.id,
    required this.title,
    this.description,
    required this.game,
    this.cityId,
    this.cityName,
    this.loungeId,
    this.loungeName,
    this.imageUrl,
    required this.status,
    required this.maxParticipants,
    required this.registeredParticipantsCount,
    required this.bracketSize,
    required this.entryFee,
    this.rules,
    this.startDate,
    this.endDate,
    this.checkInDeadline,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        game,
        cityId,
        cityName,
        loungeId,
        loungeName,
        imageUrl,
        status,
        maxParticipants,
        registeredParticipantsCount,
        bracketSize,
        entryFee,
        rules,
        startDate,
        endDate,
        checkInDeadline,
        createdAt,
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
  final bool checkedIn;
  final DateTime? checkedInAt;
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
    required this.checkedIn,
    this.checkedInAt,
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
        checkedIn,
        checkedInAt,
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
  final MatchStatus status;
  final String? proofUrl;
  final String? submittedBy;
  final DateTime? confirmationDeadline;
  final String? disputeReason;

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
    required this.status,
    this.proofUrl,
    this.submittedBy,
    this.confirmationDeadline,
    this.disputeReason,
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
        status,
        proofUrl,
        submittedBy,
        confirmationDeadline,
        disputeReason,
      ];
}

class TournamentPrizeEntity extends Equatable {
  final String id;
  final String tournamentId;
  final int placement;
  final String title;
  final String rewardType;
  final double amount;
  final String? description;

  const TournamentPrizeEntity({
    required this.id,
    required this.tournamentId,
    required this.placement,
    required this.title,
    required this.rewardType,
    required this.amount,
    this.description,
  });

  @override
  List<Object?> get props => [
        id,
        tournamentId,
        placement,
        title,
        rewardType,
        amount,
        description,
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
