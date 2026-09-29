import 'package:equatable/equatable.dart';
import 'package:playspot/features/booking/domain/entities/booking_price_quote.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class PriceChangedFailure extends Failure {
  final double oldPrice;
  final double newPrice;
  final BookingPriceQuote? newQuote;

  const PriceChangedFailure({
    required String message,
    required this.oldPrice,
    required this.newPrice,
    this.newQuote,
  }) : super(message);

  @override
  List<Object> get props => [message, oldPrice, newPrice];
}
