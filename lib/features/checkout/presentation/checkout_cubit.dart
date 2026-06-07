import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/home/data/repos/home_repos.dart';
import 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  final HomeRepository _homeRepository;

  CheckoutCubit(this._homeRepository) : super(const CheckoutState());

  void selectPaymentMethod(PaymentMethod method) {
    emit(state.copyWith(selectedMethod: method));
  }

  Future<void> processPayment({
    required String roomId,
    required String loungeId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
  }) async {
    emit(state.copyWith(status: CheckoutStatus.loading));
    
    try {
      // Create the booking in the database
      await _homeRepository.createBooking(
        roomId: roomId,
        loungeId: loungeId,
        startTime: startTime,
        endTime: endTime,
        totalPrice: totalPrice,
      );

      // If it's not cash, we would handle actual payment gateway logic here
      // For now, we just mark as success
      emit(state.copyWith(status: CheckoutStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: CheckoutStatus.failure,
        errorMessage: "Failed to confirm booking. Please try again.",
      ));
    }
  }
}
