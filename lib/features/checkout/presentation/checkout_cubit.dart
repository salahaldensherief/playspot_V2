import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/booking/data/repos/booking_repo.dart';
import 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  final BookingRepository _bookingRepository;

  CheckoutCubit(this._bookingRepository) : super(const CheckoutState());

  void selectPaymentMethod(PaymentMethod method) {
    emit(state.copyWith(selectedMethod: method));
  }

  Future<void> processPayment({
    required String roomId,
    required String roomName,
    required String loungeId,
    required String userName,
    required String userPhone,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
    required double roomPrice,
    required List<Map<String, dynamic>> addOns,
  }) async {
    emit(state.copyWith(status: CheckoutStatus.loading));
    
    final result = await _bookingRepository.createBooking(
      roomId: roomId,
      roomName: roomName,
      loungeId: loungeId,
      userName: userName,
      userPhone: userPhone,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
      roomPrice: roomPrice,
      extras: addOns,
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: failure.message,
        ));
      },
      (_) => emit(state.copyWith(status: CheckoutStatus.success)),
    );
  }
}
