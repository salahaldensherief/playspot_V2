import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  final BookingRepository _bookingRepository;
  final ProfileRepository _profileRepository;

  CheckoutCubit(this._bookingRepository, this._profileRepository) : super(const CheckoutState());

  void selectPaymentMethod(PaymentMethod method) {
    emit(state.copyWith(selectedMethod: method));
  }

  Future<void> applyVoucher(String code) async {
    if (code.isEmpty) return;
    emit(state.copyWith(status: CheckoutStatus.loading));
    final result = await _profileRepository.validateVoucherByCode(code);
    
    result.fold(
      (failure) => emit(state.copyWith(status: CheckoutStatus.failure, errorMessage: failure.message)),
      (data) {
        if (data['valid'] == true) {
          double discount = 0;
          if (data['reward_type'] == 'discount_fixed') {
            discount = (data['reward_value'] as num).toDouble();
          } else if (data['reward_type'] == 'free_hour') {
             // In case of free hour, we might need more logic or just fixed value
             discount = (data['reward_value'] as num?)?.toDouble() ?? 0;
          }
          
          emit(state.copyWith(
            status: CheckoutStatus.initial,
            selectedVoucher: Map<String, dynamic>.from(data),
            discountAmount: discount,
          ));
        } else {
          emit(state.copyWith(status: CheckoutStatus.failure, errorMessage: "Voucher invalid"));
        }
      },
    );
  }

  Future<void> selectVoucher(Map<String, dynamic> voucher) async {
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

  Future<void> processPayment(CreateBookingParams params) async {
    emit(state.copyWith(status: CheckoutStatus.loading));
    
    final result = await _bookingRepository.createBooking(params);

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
