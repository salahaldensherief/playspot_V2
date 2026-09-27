import 'dart:async';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/constants/booking_status.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/core/services/supabase_storage_service.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  final BookingRepository _bookingRepository;
  final ProfileRepository _profileRepository;
  final PreferenceManager _preferenceManager;
  final StorageService _storageService;

  CheckoutParams? _checkoutParams;
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
  Future<void> close() async {
    _holdTimer?.cancel();
    _realtimeSubscription?.cancel();
    await _releaseHold();
    return super.close();
  }

  void _startHoldTimerUntil(DateTime expiresAt, String holdToken) {
    _holdTimer?.cancel();

    final initialRemaining = expiresAt.difference(DateTime.now()).inSeconds;
    if (initialRemaining <= 0) {
      emit(
        state.copyWith(
          remainingSeconds: 0,
          isHoldExpired: true,
          holdExpiresAt: expiresAt,
          holdToken: holdToken,
        ),
      );
      unawaited(_releaseHold());
      return;
    }

    emit(
      state.copyWith(
        remainingSeconds: initialRemaining,
        isHoldExpired: false,
        holdExpiresAt: expiresAt,
        holdToken: holdToken,
      ),
    );

    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }

      final remaining = expiresAt.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        emit(
          state.copyWith(
            remainingSeconds: 0,
            isHoldExpired: true,
          ),
        );
        unawaited(_releaseHold());
        return;
      }

      emit(state.copyWith(remainingSeconds: remaining));
    });
  }

  Future<void> _releaseHold() async {
    final holdToken = state.holdToken;
    if (holdToken == null || holdToken.isEmpty) return;

    final result = await _bookingRepository.releaseBookingHold(holdToken);
    result.fold(
      (failure) => AppLogger.warning(
        'Failed to release booking hold: ${failure.message}',
      ),
      (_) {
        if (!isClosed) {
          emit(state.copyWith(clearHold: true));
        }
      },
    );
  }

  Future<void> initCheckout(
    CheckoutParams params, {
    int? completedBookingsCount,
  }) async {
    _checkoutParams = params;
    final lounge = params.lounge;
    final holdToken = params.holdToken;
    final holdExpiresAt = params.holdExpiresAt;

    if (holdToken == null ||
        holdToken.isEmpty ||
        holdExpiresAt == null ||
        !holdExpiresAt.isAfter(DateTime.now())) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          isHoldExpired: true,
          remainingSeconds: 0,
          errorMessage: AppStrings.holdExpiredMessage.tr(),
          clearHold: true,
        ),
      );
      return;
    }

    _startHoldTimerUntil(holdExpiresAt, holdToken);

    final quoteLoaded = await _refreshQuote();
    if (!quoteLoaded || isClosed) return;

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

    emit(
      state.copyWith(
        allowCashPayment: allowCash,
        isCashEnabled: isCashEnabled,
        completedBookingsCount: userBookingsCount,
        selectedMethod: defaultMethod,
      ),
    );
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
                AppStrings.bookingRejectedByLounge.tr(),
          ));
        } else {
          emit(state.copyWith(liveBookingStatus: updatedBooking.status));
        }
      },
      onError: (e, st) {
        AppLogger.error('Booking status realtime stream error', e, st);
        if (isClosed) return;
        emit(state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: AppStrings.realtimeConnectionLost.tr(),
        ));
      },
    );
  }

  List<Map<String, dynamic>> _buildRoomRequests(
    CheckoutParams params,
  ) {
    return params.rooms.map((room) {
      final breakdown = params.roomsBreakdown.firstWhere(
        (item) => item['roomId']?.toString() == room.id,
        orElse: () => const <String, dynamic>{},
      );

      return <String, dynamic>{
        'room_id': room.id,
        'play_mode': breakdown['playMode']?.toString() ??
            params.playMode ??
            'single',
        'extra_controllers':
            (breakdown['extraControllers'] as num?)?.toInt() ??
            (params.rooms.length == 1 ? params.extraControllers ?? 0 : 0),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _buildExtras(CheckoutParams params) {
    return params.addOns.map((item) {
      final extraId = item['extra_id']?.toString() ??
          item['id']?.toString() ??
          item['product_id']?.toString() ??
          '';

      return <String, dynamic>{
        'extra_id': extraId,
        'quantity': (item['quantity'] as num?)?.toInt() ?? 1,
      };
    }).toList();
  }

  Future<bool> _refreshQuote({String? voucherCode}) async {
    final params = _checkoutParams;
    final holdToken = state.holdToken ?? params?.holdToken;

    if (params == null || holdToken == null || holdToken.isEmpty) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: AppStrings.holdExpiredMessage.tr(),
          clearBookingQuote: true,
        ),
      );
      return false;
    }

    emit(state.copyWith(status: CheckoutStatus.loading));

    final result = await _bookingRepository.getBookingQuote(
      holdToken: holdToken,
      roomRequests: _buildRoomRequests(params),
      extras: _buildExtras(params),
      voucherCode: voucherCode,
    );

    if (isClosed) return false;

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: CheckoutStatus.failure,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (quote) {
        final voucher = quote['voucher'];
        final voucherMap = voucher is Map
            ? Map<String, dynamic>.from(voucher)
            : null;
        final voucherDiscount =
            (quote['voucher_discount'] as num?)?.toDouble() ?? 0.0;

        emit(
          state.copyWith(
            status: CheckoutStatus.initial,
            bookingQuote: quote,
            selectedVoucher: voucherMap,
            clearSelectedVoucher: voucherMap == null,
            discountAmount: voucherDiscount,
          ),
        );
        return true;
      },
    );
  }

  Future<void> applyVoucher(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    HapticFeedback.mediumImpact();
    await _refreshQuote(voucherCode: cleanCode);
  }

  Future<void> selectVoucher(Map<String, dynamic> voucher) async {
    final code = (voucher['code'] ?? voucher['id'])
            ?.toString()
            .trim()
            .toUpperCase() ??
        '';
    if (code.isEmpty) return;

    HapticFeedback.mediumImpact();
    await _refreshQuote(voucherCode: code);
  }

  Future<void> removeVoucher() async {
    HapticFeedback.lightImpact();
    await _refreshQuote();
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
    final holdToken = state.holdToken ?? checkoutParams.holdToken;
    if (state.isHoldExpired ||
        holdToken == null ||
        holdToken.isEmpty ||
        state.bookingQuote == null) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: AppStrings.holdExpiredMessage.tr(),
        ),
      );
      return;
    }

    emit(state.copyWith(status: CheckoutStatus.loading));

    final methodStr =
        (paymentMethod?.toLowerCase() == 'cash' ||
                state.selectedMethod == PaymentMethod.cash)
            ? 'cash'
            : 'manual_transfer';

    final effectiveAccount =
        senderAccount ?? senderWalletPhone ?? state.senderWalletNumber;

    String? receiptUrl;
    if (receiptFile != null) {
      try {
        final userId = _preferenceManager.userId() ?? 'guest';
        final tempId = 'proof_${DateTime.now().millisecondsSinceEpoch}';
        receiptUrl = await _storageService.uploadPaymentProof(
          userId: userId,
          bookingId: tempId,
          file: receiptFile,
        );
      } catch (e, st) {
        AppLogger.error('Payment proof upload failed', e, st);
        emit(
          state.copyWith(
            status: CheckoutStatus.failure,
            errorMessage: e.toString(),
          ),
        );
        return;
      }
    }

    final voucherCode = state.selectedVoucher?['code']
        ?.toString()
        .trim()
        .toUpperCase();

    final result = await _bookingRepository.createBookingsFromHold(
      holdToken: holdToken,
      roomRequests: _buildRoomRequests(checkoutParams),
      extras: _buildExtras(checkoutParams),
      voucherCode:
          voucherCode == null || voucherCode.isEmpty ? null : voucherCode,
      paymentMethod: methodStr,
      senderWalletPhone:
          methodStr == 'manual_transfer' ? effectiveAccount : null,
      receiptUrl: receiptUrl,
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: CheckoutStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
      (data) {
        final primaryBookingId =
            data['primary_booking_id']?.toString();

        if (primaryBookingId == null || primaryBookingId.isEmpty) {
          emit(
            state.copyWith(
              status: CheckoutStatus.failure,
              errorMessage: 'bookingCreationFailed',
            ),
          );
          return;
        }

        _holdTimer?.cancel();

        final returnedQuote = data['quote'];
        final quote = returnedQuote is Map
            ? Map<String, dynamic>.from(returnedQuote)
            : state.bookingQuote;

        emit(
          state.copyWith(
            clearHold: true,
            bookingQuote: quote,
            createdBookingId: primaryBookingId,
          ),
        );

        listenToBookingStatus(primaryBookingId);

        emit(
          state.copyWith(
            status: CheckoutStatus.success,
            createdBookingId: primaryBookingId,
          ),
        );
      },
    );
  }

}
