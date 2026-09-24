import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/core/services/supabase_storage_service.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  final BookingRepository _bookingRepository;
  final ProfileRepository _profileRepository;
  final PreferenceManager _preferenceManager;
  final StorageService _storageService;

  Timer? _holdTimer;
  StreamSubscription<BookingModel>? _realtimeSubscription;

  CheckoutCubit(
    this._bookingRepository,
    this._profileRepository, {
    PreferenceManager? preferenceManager,
    StorageService? storageService,
  })  : _preferenceManager = preferenceManager ?? sl<PreferenceManager>(),
        _storageService = storageService ?? sl<StorageService>(),
        super(const CheckoutState());

  @override
  Future<void> close() {
    _holdTimer?.cancel();
    _realtimeSubscription?.cancel();
    return super.close();
  }

  void startHoldTimer([int totalSeconds = 600]) {
    _holdTimer?.cancel();
    final expiresAt = DateTime.now().add(Duration(seconds: totalSeconds));
    emit(state.copyWith(
      remainingSeconds: totalSeconds,
      isHoldExpired: false,
      holdExpiresAt: expiresAt,
    ));

    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      final diff = expiresAt.difference(now).inSeconds;
      if (diff <= 0) {
        timer.cancel();
        emit(state.copyWith(
          remainingSeconds: 0,
          isHoldExpired: true,
        ));
      } else {
        emit(state.copyWith(remainingSeconds: diff));
      }
    });
  }

  Future<void> initCheckout(LoungeModel lounge, {int? completedBookingsCount}) async {
    startHoldTimer(lounge.cashGracePeriodMinutes > 0
        ? lounge.cashGracePeriodMinutes * 60
        : 600);

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

  void listenToBookingStatus(String bookingId) {
    _realtimeSubscription?.cancel();
    emit(state.copyWith(createdBookingId: bookingId));

    _realtimeSubscription = _bookingRepository.watchBookingStatus(bookingId).listen(
      (updatedBooking) {
        if (isClosed) return;

        if (updatedBooking.status == BookingStatus.upcoming) {
          emit(state.copyWith(
            liveBookingStatus: BookingStatus.upcoming,
            confirmedBooking: updatedBooking,
          ));
        } else if (updatedBooking.status == BookingStatus.cancelled) {
          emit(state.copyWith(
            liveBookingStatus: BookingStatus.cancelled,
            rejectionReason: updatedBooking.rejectionReason ??
                updatedBooking.cancellationReason ??
                'تم رفض الطلب من قبل إدارة الصالة',
          ));
        } else {
          emit(state.copyWith(liveBookingStatus: updatedBooking.status));
        }
      },
      onError: (_) {},
    );
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

  Future<void> processPayment(
    CheckoutParams checkoutParams, {
    bool isArabic = false,
    File? receiptFile,
    String? paymentMethod,
    String? senderWalletPhone,
    String? senderAccount,
    String? transactionReference,
  }) async {
    if (state.isHoldExpired) {
      emit(state.copyWith(
        status: CheckoutStatus.failure,
        errorMessage: isArabic
            ? 'انتهت المهلة الزمنية لحجز هذا الموعد المؤقت (10 دقائق). يرجى إعادة اختيار الموعد.'
            : 'Hold time for this slot has expired (10 minutes). Please reselect a slot.',
      ));
      return;
    }

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
    final userId = _preferenceManager.userId() ?? "";

    final String methodStr = (paymentMethod?.toLowerCase() == 'cash' || state.selectedMethod == PaymentMethod.cash)
        ? 'cash'
        : 'manual_transfer';

    final effectiveAccount = senderAccount ?? senderWalletPhone ?? state.senderWalletNumber;

    final roomsToBook = checkoutParams.rooms.isNotEmpty
        ? checkoutParams.rooms
        : [checkoutParams.room];

    String? primaryBookingId;

    String? receiptUrl;
    if (receiptFile != null) {
      try {
        final uId = userId.isNotEmpty ? userId : 'guest';
        final tempId = 'proof_${DateTime.now().millisecondsSinceEpoch}';
        receiptUrl = await _storageService.uploadPaymentProof(
          userId: uId,
          bookingId: tempId,
          file: receiptFile,
        );
      } catch (_) {}
    }

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
        proofImageUrl: receiptUrl,
        paymentMethod: methodStr,
        senderWalletPhone: methodStr == 'manual_transfer' ? effectiveAccount : null,
        senderAccount: methodStr == 'manual_transfer' ? effectiveAccount : null,
        transactionReference: transactionReference,
        holdExpiresAt: state.holdExpiresAt,
        expiresAt: state.holdExpiresAt,
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

    // Re-upload under final booking ID path: payment-proofs/{userId}/{bookingId}.jpg
    if (receiptFile != null && primaryBookingId != null) {
      try {
        final uId = userId.isNotEmpty ? userId : 'guest';
        await _storageService.uploadPaymentProof(
          userId: uId,
          bookingId: primaryBookingId!,
          file: receiptFile,
        );
      } catch (_) {}
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

    if (primaryBookingId != null) {
      listenToBookingStatus(primaryBookingId!);
    }

    try {
      sl<ProfileCubit>().getUserData();
    } catch (_) {}
    emit(state.copyWith(
      status: CheckoutStatus.success,
      createdBookingId: primaryBookingId,
    ));
  }
}
