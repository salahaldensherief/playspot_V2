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
    
    final result = await _homeRepository.createBooking(
      roomId: roomId,
      loungeId: loungeId,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: CheckoutStatus.failure,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(status: CheckoutStatus.success)),
    );
  }
}
