import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/core/services/supabase_storage_service.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  final BookingRepository _bookingRepository;
  final ProfileRepository _profileRepository;
  final PreferenceManager _preferenceManager;
  final StorageService _storageService;

  CheckoutCubit(
    this._bookingRepository,
    this._profileRepository, {
    PreferenceManager? preferenceManager,
    StorageService? storageService,
  })  : _preferenceManager = preferenceManager ?? sl<PreferenceManager>(),
        _storageService = storageService ?? sl<StorageService>(),
        super(const CheckoutState());

  Future<void> initCheckout(LoungeModel lounge, {int? completedBookingsCount}) async {
    int userBookingsCount = completedBookingsCount ?? 0;
    if (completedBookingsCount == null) {
      final result = await _profileRepository.getTotalBookingsCount();
      result.fold(
        (_) => userBookingsCount = 0,
        (count) => userBookingsCount = count,
      );
    }

    final bool allowCash = lounge.allowCashPayment;
    bool isCashEnabled = true;

    if (allowCash && lounge.requirePrepaidFirstTime && userBookingsCount == 0) {
      isCashEnabled = false;
    }

    PaymentMethod defaultMethod = state.selectedMethod;
    if (!allowCash || (!isCashEnabled && defaultMethod == PaymentMethod.cash)) {
      defaultMethod = PaymentMethod.vodafoneCash;
    }

    emit(state.copyWith(
      allowCashPayment: allowCash,
      isCashEnabled: isCashEnabled,
      completedBookingsCount: userBookingsCount,
      selectedMethod: defaultMethod,
    ));
  }

  void selectPaymentMethod(PaymentMethod method) {
    if (method == PaymentMethod.cash && (!state.allowCashPayment || !state.isCashEnabled)) {
      HapticFeedback.vibrate();
      return;
    }
    HapticFeedback.selectionClick();
    emit(state.copyWith(selectedMethod: method));
  }

  void updateSenderWalletNumber(String value) {
    emit(state.copyWith(senderWalletNumber: value.trim()));
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
    File? receiptFile,
    String? paymentMethod,
    String? senderWalletPhone,
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

    final userName = _preferenceManager.fullName() ?? "";
    final userPhone = _preferenceManager.phoneNumber() ?? "";

    String? receiptUrl;
    if (receiptFile != null) {
      try {
        final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
        receiptUrl = await _storageService.uploadFile(
          bucket: 'receipts',
          path: fileName,
          file: receiptFile,
        );
      } catch (_) {}
    }


    final String methodStr = (paymentMethod?.toLowerCase() == 'cash' || state.selectedMethod == PaymentMethod.cash)
        ? 'cash'
        : 'manual_transfer';

    final roomsToBook = checkoutParams.rooms.isNotEmpty
        ? checkoutParams.rooms
        : [checkoutParams.room];

    String? primaryBookingId;

    for (int i = 0; i < roomsToBook.length; i++) {
      final currentRoom = roomsToBook[i];
      final targetLoungeId = currentRoom.loungeId.isNotEmpty
          ? currentRoom.loungeId
          : checkoutParams.lounge.id;

      final breakdown = checkoutParams.roomsBreakdown.firstWhere(
        (b) => b['roomId'] == currentRoom.id,
        orElse: () => <String, dynamic>{},
      );

      final double origRoomPrice = (breakdown['originalSubtotal'] as num?)?.toDouble() ??
          (checkoutParams.rooms.length == 1
              ? checkoutParams.originalRoomSubtotal
              : (currentRoom.hourlyRateSingle * (checkoutParams.duration / 60.0)));

      final double discRoomPrice = (breakdown['discountedSubtotal'] as num?)?.toDouble() ??
          (checkoutParams.rooms.length == 1
              ? checkoutParams.discountedRoomSubtotal
              : origRoomPrice);

      final double roomDiscount = (breakdown['discountAmount'] as num?)?.toDouble() ??
          (checkoutParams.rooms.length == 1 ? checkoutParams.discountAmount : 0.0);

      final isFirst = i == 0;
      final double totalDiscount = roomDiscount + (isFirst ? state.discountAmount : 0.0);
      final double roomAddonsTotal = isFirst ? checkoutParams.addonsTotal : 0.0;
      final double roomTotalPrice = discRoomPrice + roomAddonsTotal - (isFirst ? state.discountAmount : 0.0);
      final List<Map<String, dynamic>> roomAddons = isFirst ? checkoutParams.addOns : const [];
      final String? roomMode = breakdown['playMode']?.toString() ??
          (checkoutParams.rooms.length == 1 ? checkoutParams.playMode : 'single');

      final params = CreateBookingParams(
        roomId: currentRoom.id,
        roomName: currentRoom.getName(isArabic),
        loungeId: targetLoungeId,
        userName: userName,
        userPhone: userPhone,
        startTime: startDateTime,
        endTime: endDateTime,
        originalRoomPrice: origRoomPrice,
        discountedRoomPrice: discRoomPrice,
        roomPrice: discRoomPrice,
        discountAmount: totalDiscount,
        discountPercentage: checkoutParams.discountPercentage,
        discountLabel: checkoutParams.discountLabel,
        discountReason: checkoutParams.discountLabel,
        discountSource: checkoutParams.discountSource,
        durationHours: checkoutParams.duration / 60.0,
        roomSubtotal: discRoomPrice,
        addonsTotal: roomAddonsTotal,
        totalPrice: roomTotalPrice,
        addOns: roomAddons,
        playMode: roomMode,
        receiptUrl: receiptUrl,
        paymentMethod: methodStr,
        senderWalletPhone: methodStr == 'manual_transfer'
            ? (senderWalletPhone ?? state.senderWalletNumber)
            : null,
      );

      final result = await _bookingRepository.createBooking(params);

      bool hasFailed = false;
      result.fold(
        (failure) {
          hasFailed = true;
          emit(state.copyWith(
            status: CheckoutStatus.failure,
            errorMessage: failure.message,
          ));
        },
        (bookingData) {
          if (isFirst) {
            primaryBookingId = bookingData['id']?.toString();
          }
        },
      );

      if (hasFailed) return;
    }

    if (state.selectedVoucher != null && primaryBookingId != null) {
      final voucherCode = (state.selectedVoucher!['code'] ?? state.selectedVoucher!['id'])
          ?.toString()
          .trim()
          .toUpperCase() ?? '';
      if (voucherCode.isNotEmpty) {
        await _profileRepository.consumeVoucherByCode(
          code: voucherCode,
          bookingId: primaryBookingId!,
        );
      }
    }

    try {
      sl<ProfileCubit>().getUserData();
    } catch (_) {}
    emit(state.copyWith(status: CheckoutStatus.success));
  }
}
