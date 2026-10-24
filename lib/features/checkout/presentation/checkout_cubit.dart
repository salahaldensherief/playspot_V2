import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  bool _closing = false;
  bool _paymentInFlight = false;
  int _quoteRequestVersion = 0;
  int _initRequestVersion = 0;
  int _bookingStatusVersion = 0;
  bool get _inactive => _closing || isClosed;
  String? get _recoveryKey {
    final actor = _preferenceManager.userId();
    return actor == null || actor.isEmpty ? null : 'checkout.pending.$actor';
  }

  String _newOperationId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

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
    if (_closing) return;
    _closing = true;
    ++_quoteRequestVersion;
    ++_initRequestVersion;
    _holdTimer?.cancel();
    await _realtimeSubscription?.cancel();
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
      if (_inactive) {
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
    if (_paymentInFlight || state.status == CheckoutStatus.pending) return;
    final holdToken = state.holdToken;
    if (holdToken == null || holdToken.isEmpty) return;

    final result = await _bookingRepository.releaseBookingHold(holdToken);
    result.fold(
      (failure) => AppLogger.warning(
        'Failed to release booking hold: ${failure.message}',
      ),
      (_) {
        if (!_inactive && state.holdToken == holdToken) {
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
    if (_inactive || _paymentInFlight) return;
    ++_quoteRequestVersion;
    final initVersion = ++_initRequestVersion;
    _checkoutParams = params;
    _holdTimer?.cancel();
    ++_bookingStatusVersion;
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;
    final recoveryKey = _recoveryKey;
    if (recoveryKey != null &&
        _preferenceManager.getValue(recoveryKey).isNotEmpty) {
      await retryPendingRecovery();
      return;
    }
    emit(
      CheckoutState(
        status: CheckoutStatus.loading,
        selectedMethod: state.selectedMethod,
      ),
    );

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
    if (_inactive || initVersion != _initRequestVersion) return;

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

  Future<void> retryPendingRecovery() async {
    if (_inactive) return;
    final key = _recoveryKey;
    if (key == null) return;
    final saved = _preferenceManager.getValue(key);
    if (saved.isEmpty) return;
    String operationId;
    String method;
    try {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      operationId = data['operation_id'] as String;
      method = data['payment_method'] as String? ?? 'cash';
    } catch (_) {
      emit(state.copyWith(status: CheckoutStatus.pending));
      return;
    }
    emit(state.copyWith(status: CheckoutStatus.loading));
    final lookup = await _bookingRepository.recoverBookingCheckout(operationId);
    if (_inactive) return;
    Map<String, dynamic>? recovered;
    lookup.fold((_) {}, (value) => recovered = value);
    final bookingId = recovered?['primary_booking_id']?.toString();
    if (bookingId == null || bookingId.isEmpty) {
      emit(state.copyWith(status: CheckoutStatus.pending));
      return;
    }
    await _preferenceManager.clearValue(key);
    if (_inactive) return;
    _clearLocalHold();
    listenToBookingStatus(bookingId);
    emit(
      state.copyWith(
        status: CheckoutStatus.success,
        createdBookingId: bookingId,
        paymentProofUploadFailed: method == 'manual_transfer',
      ),
    );
  }

  void selectPaymentMethod(PaymentMethod method) {
    if (_inactive || _paymentInFlight || state.createdBookingId != null) return;
    if (method == PaymentMethod.cash &&
        (!state.allowCashPayment || !state.isCashEnabled)) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.selectionClick();
    emit(state.copyWith(selectedMethod: method));
  }

  void updateSenderWalletNumber(String value) {
    if (_inactive || _paymentInFlight || state.createdBookingId != null) return;
    emit(state.copyWith(senderWalletNumber: value.trim()));
  }

  void listenToBookingStatus(String bookingId) {
    if (_inactive) return;
    _realtimeSubscription?.cancel();
    final subscriptionVersion = ++_bookingStatusVersion;
    emit(state.copyWith(createdBookingId: bookingId));

    _realtimeSubscription = _bookingRepository
        .watchBookingStatus(bookingId)
        .listen(
          (updatedBooking) {
            if (_inactive || subscriptionVersion != _bookingStatusVersion) {
              return;
            }

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
            if (_inactive || subscriptionVersion != _bookingStatusVersion) {
              return;
            }

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
    if (_inactive || _paymentInFlight || state.createdBookingId != null) return;
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    HapticFeedback.mediumImpact();
    await _refreshServerQuote(voucherCode: cleanCode);
  }

  Future<void> selectVoucher(Map<String, dynamic> voucher) async {
    if (_inactive || _paymentInFlight || state.createdBookingId != null) return;
    final code =
        (voucher['code'] ?? voucher['id'])?.toString().trim().toUpperCase() ??
        '';
    if (code.isEmpty) return;

    await _refreshServerQuote(voucherCode: code);
  }

  Future<void> removeVoucher() async {
    if (_inactive || _paymentInFlight || state.createdBookingId != null) return;
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
    if (_inactive || _paymentInFlight || state.createdBookingId != null) return;
    final requestVersion = ++_quoteRequestVersion;
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

    if (_inactive || requestVersion != _quoteRequestVersion) return;

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
            clearPriceChangedFailure: true,
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
    if (_inactive ||
        _paymentInFlight ||
        state.createdBookingId != null ||
        state.status == CheckoutStatus.loading ||
        state.status == CheckoutStatus.pending) {
      return;
    }
    ++_quoteRequestVersion;

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

    _paymentInFlight = true;
    try {
      emit(
        state.copyWith(
          status: CheckoutStatus.loading,
          paymentProofUploadFailed: false,
          clearPriceChangedFailure: true,
        ),
      );

      final method =
          (paymentMethod == null
              ? state.selectedMethod == PaymentMethod.cash
              : paymentMethod.toLowerCase() == 'cash')
          ? 'cash'
          : 'manual_transfer';

      final effectiveAccount =
          senderAccount ?? senderWalletPhone ?? state.senderWalletNumber;

      final voucherCode = state.selectedVoucher?['code']
          ?.toString()
          .trim()
          .toUpperCase();

      final recoveryKey = _recoveryKey;
      if (recoveryKey == null) {
        emit(
          state.copyWith(
            status: CheckoutStatus.failure,
            errorMessage: AppStrings.somethingWentWrong.tr(),
          ),
        );
        return;
      }
      final operationId = _newOperationId();
      await _preferenceManager.saveValue(
        recoveryKey,
        jsonEncode({
          'operation_id': operationId,
          'hold_token': holdToken,
          'payment_method': method,
        }),
      );

      final result = await _bookingRepository.createBookingCheckout(
        operationId: operationId,
        holdToken: holdToken,
        roomRequests: _buildRoomRequests(checkoutParams),
        extraItems: _buildExtraItems(checkoutParams),
        voucherCode: voucherCode == null || voucherCode.isEmpty
            ? null
            : voucherCode,
        paymentMethod: method,
        senderWalletPhone: method == 'manual_transfer'
            ? effectiveAccount
            : null,
        receiptUrl: null,
      );

      if (_inactive) return;

      String? checkoutError;
      Map<String, dynamic>? checkoutData;
      result.fold((failure) {
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
      }, (data) => checkoutData = data);

      if (state.priceChangedFailure != null) {
        await _preferenceManager.clearValue(recoveryKey);
        return;
      }

      if (checkoutError != null || checkoutData == null) {
        await retryPendingRecovery();
        return;
      }

      final primaryBookingId = checkoutData!['primary_booking_id']?.toString();
      final quote = checkoutData!['quote'];

      if (primaryBookingId == null || primaryBookingId.isEmpty) {
        emit(state.copyWith(status: CheckoutStatus.pending));
        return;
      }

      await _preferenceManager.clearValue(recoveryKey);
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
          if (_inactive) return;

          if (receiptPath == null || receiptPath.isEmpty) {
            throw StateError('Payment proof upload returned an empty path');
          }

          final attachResult = await _bookingRepository.attachBookingReceipt(
            bookingId: primaryBookingId,
            receiptPath: receiptPath,
          );
          if (_inactive) return;

          String? attachError;
          attachResult.fold((failure) => attachError = failure.message, (_) {});

          final resolvedAttachError = attachError;
          if (resolvedAttachError != null) {
            throw StateError(resolvedAttachError);
          }
        } catch (error, stackTrace) {
          if (_inactive) return;
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
    } finally {
      _paymentInFlight = false;
    }
  }
}
