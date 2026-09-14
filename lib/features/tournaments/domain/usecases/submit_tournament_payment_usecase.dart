import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../repositories/tournaments_repository.dart';

class SubmitTournamentPaymentUseCase {
  final TournamentsRepository repository;

  SubmitTournamentPaymentUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String participantId,
    required String tournamentId,
    required String userId,
    required double amount,
    required String paymentMethod,
    required File receiptFile,
  }) {
    return repository.submitTournamentPayment(
      participantId: participantId,
      tournamentId: tournamentId,
      userId: userId,
      amount: amount,
      paymentMethod: paymentMethod,
      receiptFile: receiptFile,
    );
  }
}
