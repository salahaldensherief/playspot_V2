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
import 'package:playspot/core/error/failures.dart';
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
  }) : _preferenceManager = preferenceManager ?? sl<PreferenceManager>(),
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
        emit(state.copyWith(remainingSeconds: 0, isHoldExpired: true));
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

  void _clearLocalHold() {
    _holdTimer?.cancel();
    emit(state.copyWith(clearHold: true));
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

    int userBookingsCount = completedBookingsCount ?? 0;
    if (completedBookingsCount == null) {
      final result = await _profileRepository.getTotalBookingsCount();
      result.fold(
        (_) => userBookingsCount = 0,
        (count) => userBookingsCount = count,
      );
    }

    final allowCash = lounge.allowCashPayment;
    var isCashEnabled = true;

    if (allowCash && lounge.requirePrepaidFirstTime && userBookingsCount == 0) {
      isCashEnabled = false;
    }

    var defaultMethod = state.selectedMethod;
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

    await _refreshServerQuote();
  }

  void selectPaymentMethod(PaymentMethod method) {
    if (method == PaymentMethod.cash &&
        (!state.allowCashPayment || !state.isCashEnabled)) {
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

    _realtimeSubscription = _bookingRepository
        .watchBookingStatus(bookingId)
        .listen(
          (updatedBooking) {
            if (isClosed) return;

            if (updatedBooking.status == BookingStatus.upcoming) {
              emit(
                state.copyWith(
                  liveBookingStatus: BookingStatus.upcoming,
                  confirmedBooking: updatedBooking,
                ),
              );
            } else if (updatedBooking.status == BookingStatus.cancelled) {
              emit(
                state.copyWith(
                  liveBookingStatus: BookingStatus.cancelled,
                  rejectionReason:
                      updatedBooking.rejectionReason ??
                      updatedBooking.cancellationReason ??
                      AppStrings.bookingRejectedByLounge.tr(),
                ),
              );
            } else {
              emit(state.copyWith(liveBookingStatus: updatedBooking.status));
            }
          },
          onError: (error, stackTrace) {
            AppLogger.error(
              'Booking status realtime stream error',
              error,
              stackTrace,
            );
            if (isClosed) return;

            emit(
              state.copyWith(
                status: CheckoutStatus.failure,
                errorMessage: AppStrings.realtimeConnectionLost.tr(),
              ),
            );
          },
        );
  }

  Future<void> applyVoucher(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    HapticFeedback.mediumImpact();
    await _refreshServerQuote(voucherCode: cleanCode);
  }

  Future<void> selectVoucher(Map<String, dynamic> voucher) async {
    final code =
        (voucher['code'] ?? voucher['id'])?.toString().trim().toUpperCase() ??
        '';
    if (code.isEmpty) return;

    await _refreshServerQuote(voucherCode: code);
  }

  Future<void> removeVoucher() async {
    HapticFeedback.lightImpact();
    emit(state.copyWith(clearVoucher: true, status: CheckoutStatus.loading));
    await _refreshServerQuote();
  }

  Future<void> retryServerQuote() async {
    if (state.isHoldExpired || state.status == CheckoutStatus.loading) {
      return;
    }
    await _refreshServerQuote(
      voucherCode: state.selectedVoucher?['code']?.toString(),
    );
  }

  Future<void> _refreshServerQuote({String? voucherCode}) async {
    final params = _checkoutParams;
    final holdToken = state.holdToken ?? params?.holdToken;

    if (params == null || holdToken == null || holdToken.isEmpty) {
      return;
    }

    final cleanVoucher = voucherCode?.trim().toUpperCase();
    emit(state.copyWith(status: CheckoutStatus.loading));

    final result = await _bookingRepository.quoteBookingCheckout(
      holdToken: holdToken,
      roomRequests: _buildRoomRequests(params),
      extraItems: _buildExtraItems(params),
      voucherCode: cleanVoucher == null || cleanVoucher.isEmpty
          ? null
          : cleanVoucher,
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
      (quote) {
        final voucherDiscount =
            (quote['voucher_discount'] as num?)?.toDouble() ?? 0.0;
        final quotedVoucherCode = quote['voucher_code']?.toString();

        emit(
          state.copyWith(
            status: CheckoutStatus.initial,
            serverQuote: quote,
            selectedVoucher:
                quotedVoucherCode == null || quotedVoucherCode.isEmpty
                ? null
                : <String, dynamic>{'code': quotedVoucherCode},
            clearVoucher:
                quotedVoucherCode == null || quotedVoucherCode.isEmpty,
            discountAmount: voucherDiscount,
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _buildRoomRequests(CheckoutParams params) {
    final rooms = params.rooms.isNotEmpty ? params.rooms : [params.room];

    return rooms.map((room) {
      final breakdown = params.roomsBreakdown.firstWhere(
        (item) => item['roomId']?.toString() == room.id,
        orElse: () => const <String, dynamic>{},
      );

      final playMode =
          breakdown['playMode']?.toString() ??
          (rooms.length == 1 ? params.playMode : null) ??
          'single';

      final extraControllers =
          (breakdown['extraControllers'] as num?)?.toInt() ??
          (rooms.length == 1 ? params.extraControllers : null) ??
          0;

      return <String, dynamic>{
        'room_id': room.id,
        'play_mode': playMode,
        'extra_controllers': extraControllers,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _buildExtraItems(CheckoutParams params) {
    return params.addOns.map((item) {
      final extraId =
          item['extra_id'] ??
          item['id'] ??
          item['product_id'] ??
          item['item_id'];

      return <String, dynamic>{
        'extra_id': extraId?.toString() ?? '',
        'quantity': (item['quantity'] as num?)?.toInt() ?? 1,
      };
    }).toList();
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
    if (state.status == CheckoutStatus.loading) return;

    final holdToken = state.holdToken ?? checkoutParams.holdToken;
    if (state.isHoldExpired || holdToken == null || holdToken.isEmpty) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: AppStrings.holdExpiredMessage.tr(),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: CheckoutStatus.loading,
        paymentProofUploadFailed: false,
      ),
    );

    final method =
        (paymentMethod?.toLowerCase() == 'cash' ||
            state.selectedMethod == PaymentMethod.cash)
        ? 'cash'
        : 'manual_transfer';

    final effectiveAccount =
        senderAccount ?? senderWalletPhone ?? state.senderWalletNumber;

    final voucherCode = state.selectedVoucher?['code']
        ?.toString()
        .trim()
        .toUpperCase();

    final result = await _bookingRepository.createBookingCheckout(
      holdToken: holdToken,
      roomRequests: _buildRoomRequests(checkoutParams),
      extraItems: _buildExtraItems(checkoutParams),
      voucherCode: voucherCode == null || voucherCode.isEmpty
          ? null
          : voucherCode,
      paymentMethod: method,
      senderWalletPhone: method == 'manual_transfer' ? effectiveAccount : null,
      receiptUrl: null,
    );

    if (isClosed) return;

    String? checkoutError;
    Map<String, dynamic>? checkoutData;
    result.fold(
      (failure) {
        if (failure is PriceChangedFailure) {
          emit(
            state.copyWith(
              status: CheckoutStatus.failure,
              priceChangedFailure: failure,
              errorMessage: failure.message,
            ),
          );
        } else {
          checkoutError = failure.message;
        }
      },
      (data) => checkoutData = data,
    );

    if (state.priceChangedFailure != null) {
      return;
    }

    if (checkoutError != null || checkoutData == null) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: checkoutError ?? AppStrings.somethingWentWrong.tr(),
        ),
      );
      return;
    }

    final primaryBookingId = checkoutData!['primary_booking_id']?.toString();
    final quote = checkoutData!['quote'];

    if (primaryBookingId == null || primaryBookingId.isEmpty) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: AppStrings.somethingWentWrong.tr(),
        ),
      );
      return;
    }

    _clearLocalHold();

    if (receiptFile != null && method == 'manual_transfer') {
      try {
        final userId = _preferenceManager.userId();
        if (userId == null || userId.isEmpty) {
          throw StateError('Authenticated user id is missing');
        }

        final receiptPath = await _storageService.uploadPaymentProof(
          userId: userId,
          bookingId: primaryBookingId,
          file: receiptFile,
        );

        if (receiptPath == null || receiptPath.isEmpty) {
          throw StateError('Payment proof upload returned an empty path');
        }

        final attachResult = await _bookingRepository.attachBookingReceipt(
          bookingId: primaryBookingId,
          receiptPath: receiptPath,
        );

        String? attachError;
        attachResult.fold((failure) => attachError = failure.message, (_) {});

        final resolvedAttachError = attachError;
        if (resolvedAttachError != null) {
          throw StateError(resolvedAttachError);
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'Payment proof attach failed for booking $primaryBookingId',
          error,
          stackTrace,
        );

        // The authoritative checkout already committed the booking. Treat the
        // receipt as a follow-up failure so the user cannot mistake an existing
        // booking for a failed checkout and submit it again.
        emit(
          state.copyWith(
            createdBookingId: primaryBookingId,
            paymentProofUploadFailed: true,
          ),
        );
      }
    }

    if (quote is Map) {
      emit(state.copyWith(serverQuote: Map<String, dynamic>.from(quote)));
    }

    listenToBookingStatus(primaryBookingId);

    emit(
      state.copyWith(
        status: CheckoutStatus.success,
        createdBookingId: primaryBookingId,
      ),
    );
  }
}
