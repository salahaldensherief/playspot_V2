import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  final BookingRepository _bookingRepository;
  final ProfileRepository _profileRepository;

  CheckoutCubit(this._bookingRepository, this._profileRepository) : super(const CheckoutState());

  void selectPaymentMethod(PaymentMethod method) {
    HapticFeedback.selectionClick();
    emit(state.copyWith(selectedMethod: method));
  }

  Future<void> applyVoucher(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    HapticFeedback.mediumImpact();
    emit(state.copyWith(status: CheckoutStatus.loading));
    final result = await _profileRepository.validateVoucherByCode(cleanCode);

    result.fold(
      (failure) => emit(state.copyWith(status: CheckoutStatus.failure, errorMessage: failure.message)),
      (data) {
        if (data['valid'] == true) {
          double discount = 0;
          if (data['reward_type'] == 'discount_fixed') {
            discount = (data['reward_value'] as num).toDouble();
          } else if (data['reward_type'] == 'free_hour') {
            discount = (data['reward_value'] as num?)?.toDouble() ?? 0;
          }

          emit(state.copyWith(
            status: CheckoutStatus.initial,
            selectedVoucher: Map<String, dynamic>.from(data),
            discountAmount: discount,
          ));
        } else {
          final errorMsg = data['error']?.toString() ?? "Voucher invalid";
          emit(state.copyWith(status: CheckoutStatus.failure, errorMessage: errorMsg));
        }
      },
    );
  }

  Future<void> selectVoucher(Map<String, dynamic> voucher) async {
    final code = (voucher['code'] ?? voucher['id'])?.toString().trim().toUpperCase() ?? '';
    if (code.isEmpty) return;

    HapticFeedback.mediumImpact();
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
            discount = (data['reward_value'] as num?)?.toDouble() ?? 0;
          }

          emit(state.copyWith(
            status: CheckoutStatus.initial,
            selectedVoucher: Map<String, dynamic>.from(data),
            discountAmount: discount,
          ));
        } else {
          final errorMsg = data['error']?.toString() ?? "Voucher invalid";
          emit(state.copyWith(status: CheckoutStatus.failure, errorMessage: errorMsg));
        }
      },
    );
  }

  void removeVoucher() {
    HapticFeedback.lightImpact();
    emit(state.copyWith(selectedVoucher: null, discountAmount: 0));
  }

  /// Refactored: Moves user data extraction, date calculations, and discount math out of UI layer into Cubit
  Future<void> processPayment(
    CheckoutParams checkoutParams, {
    bool isArabic = false,
  }) async {
    emit(state.copyWith(status: CheckoutStatus.loading));

    final startDateTime = DateTime(
      checkoutParams.date.year,
      checkoutParams.date.month,
      checkoutParams.date.day,
      checkoutParams.startTime.hour,
      checkoutParams.startTime.minute,
    );
    final endDateTime = startDateTime.add(Duration(minutes: checkoutParams.duration));

    final pref = sl<PreferenceManager>();
    final userName = pref.fullName() ?? "";
    final userPhone = pref.phoneNumber() ?? "";

    final totalDiscount = checkoutParams.discountAmount + state.discountAmount;
    final finalPrice = checkoutParams.totalPrice - state.discountAmount;

    final targetLoungeId = checkoutParams.room.loungeId.isNotEmpty
        ? checkoutParams.room.loungeId
        : checkoutParams.lounge.id;

    final params = CreateBookingParams(
      roomId: checkoutParams.room.id,
      roomName: checkoutParams.room.getName(isArabic),
      loungeId: targetLoungeId,
      userName: userName,
      userPhone: userPhone,
      startTime: startDateTime,
      endTime: endDateTime,
      originalRoomPrice: checkoutParams.originalRoomSubtotal,
      discountedRoomPrice: checkoutParams.discountedRoomSubtotal,
      roomPrice: checkoutParams.discountedRoomSubtotal,
      discountAmount: totalDiscount,
      discountPercentage: checkoutParams.discountPercentage,
      discountLabel: checkoutParams.discountLabel,
      discountReason: checkoutParams.discountLabel,
      discountSource: checkoutParams.discountSource,
      durationHours: checkoutParams.duration / 60.0,
      roomSubtotal: checkoutParams.discountedRoomSubtotal,
      addonsTotal: checkoutParams.addonsTotal,
      totalPrice: finalPrice,
      addOns: checkoutParams.addOns,
      playMode: checkoutParams.playMode,
    );

    final result = await _bookingRepository.createBooking(params);

    result.fold(
      (failure) => emit(state.copyWith(
        status: CheckoutStatus.failure,
        errorMessage: failure.message,
      )),
      (bookingData) async {
        if (state.selectedVoucher != null) {
          final bookingId = bookingData['id'].toString();
          final voucherCode = (state.selectedVoucher!['code'] ?? state.selectedVoucher!['id'])?.toString().trim().toUpperCase() ?? '';
          if (voucherCode.isNotEmpty) {
            await _profileRepository.consumeVoucherByCode(
              code: voucherCode,
              bookingId: bookingId,
            );
          }
        }
        try {
          sl<ProfileCubit>().getUserData();
        } catch (_) {}
        emit(state.copyWith(status: CheckoutStatus.success));
      },
    );
  }
}
