import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/booking/data/repos/booking_repo.dart';
import 'package:playspot/features/profile/data/repos/profile_repo.dart';
import 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  final BookingRepository _bookingRepository;
  final ProfileRepository _profileRepository;

  CheckoutCubit(this._bookingRepository, this._profileRepository) : super(const CheckoutState());

  void selectPaymentMethod(PaymentMethod method) {
    emit(state.copyWith(selectedMethod: method));
  }

  Future<void> applyVoucher(Map<String, dynamic> voucher) async {
    emit(state.copyWith(status: CheckoutStatus.loading));
    final result = await _profileRepository.validateVoucher(voucher['id']);
    
    result.fold(
      (failure) => emit(state.copyWith(status: CheckoutStatus.failure, errorMessage: failure.message)),
      (data) {
        if (data['valid'] == true) {
          double discount = 0;
          if (data['reward_type'] == 'discount_fixed') {
            discount = (data['reward_value'] as num).toDouble();
          }
          // Note: Backend handles the exact value, we just display it
          
          emit(state.copyWith(
            status: CheckoutStatus.initial,
            selectedVoucher: voucher,
            discountAmount: discount,
          ));
        } else {
          emit(state.copyWith(status: CheckoutStatus.failure, errorMessage: "Voucher invalid"));
        }
      },
    );
  }

  void removeVoucher() {
    emit(state.copyWith(selectedVoucher: null, discountAmount: 0));
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
    String? playMode,
  }) async {
    emit(state.copyWith(status: CheckoutStatus.loading));
    
    final finalPrice = totalPrice - state.discountAmount;

    final result = await _bookingRepository.createBooking(
      roomId: roomId,
      roomName: roomName,
      loungeId: loungeId,
      userName: userName,
      userPhone: userPhone,
      startTime: startTime,
      endTime: endTime,
      totalPrice: finalPrice,
      roomPrice: roomPrice,
      extras: addOns,
      playMode: playMode,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: CheckoutStatus.failure,
        errorMessage: failure.message,
      )),
      (bookingData) async {
        if (state.selectedVoucher != null) {
          final bookingId = bookingData['id'].toString();
          await _profileRepository.consumeVoucher(
            voucherId: state.selectedVoucher!['id'],
            bookingId: bookingId,
          );
        }
        emit(state.copyWith(status: CheckoutStatus.success));
      },
    );
  }
}
