import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/services/supabase_storage_service.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/checkout/presentation/checkout_cubit.dart';
import 'package:playspot/features/checkout/presentation/checkout_state.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';

class MockBookingRepository extends Mock implements BookingRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockPreferenceManager extends Mock implements PreferenceManager {}

class MockStorageService extends Mock implements StorageService {}

class MockCheckoutParams extends Mock implements CheckoutParams {}

class MockRoomModel extends Mock implements RoomModel {}

class MockLoungeModel extends Mock implements LoungeModel {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(File('test-payment-proof.jpg'));
  });

  late MockBookingRepository bookingRepository;
  late MockProfileRepository profileRepository;
  late MockPreferenceManager preferenceManager;
  late MockStorageService storageService;
  late CheckoutCubit cubit;

  setUp(() {
    bookingRepository = MockBookingRepository();
    profileRepository = MockProfileRepository();
    preferenceManager = MockPreferenceManager();
    storageService = MockStorageService();
    when(() => preferenceManager.getValue(any())).thenReturn('');
    when(
      () => preferenceManager.saveValue(any(), any()),
    ).thenAnswer((_) async {});
    when(() => preferenceManager.clearValue(any())).thenAnswer((_) async {});
    cubit = CheckoutCubit(
      bookingRepository,
      profileRepository,
      preferenceManager: preferenceManager,
      storageService: storageService,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  MockCheckoutParams validParams() {
    final params = MockCheckoutParams();
    final room = MockRoomModel();
    when(() => params.holdToken).thenReturn('hold-token');
    when(() => params.rooms).thenReturn([room]);
    when(() => params.roomsBreakdown).thenReturn(const []);
    when(() => params.playMode).thenReturn('single');
    when(() => params.extraControllers).thenReturn(0);
    when(() => params.addOns).thenReturn(const []);
    when(() => room.id).thenReturn('room-1');
    when(() => preferenceManager.userId()).thenReturn('user-1');
    return params;
  }

  test(
    'late voucher quote cannot overwrite the latest selected voucher',
    () async {
      final params = validParams();
      final lounge = MockLoungeModel();
      when(() => params.lounge).thenReturn(lounge);
      when(
        () => params.holdExpiresAt,
      ).thenReturn(DateTime.now().add(const Duration(minutes: 10)));
      when(() => lounge.allowCashPayment).thenReturn(true);
      when(() => lounge.requirePrepaidFirstTime).thenReturn(false);
      when(
        () => bookingRepository.releaseBookingHold(any()),
      ).thenAnswer((_) async => const Right(null));
      final first = Completer<Either<Failure, Map<String, dynamic>>>();
      final second = Completer<Either<Failure, Map<String, dynamic>>>();
      when(
        () => bookingRepository.quoteBookingCheckout(
          holdToken: any(named: 'holdToken'),
          roomRequests: any(named: 'roomRequests'),
          extraItems: any(named: 'extraItems'),
          voucherCode: any(named: 'voucherCode'),
        ),
      ).thenAnswer((invocation) {
        final voucher = invocation.namedArguments[#voucherCode];
        if (voucher == 'FIRST') return first.future;
        if (voucher == 'SECOND') return second.future;
        return Future.value(const Right({'final_total': 100}));
      });
      await cubit.initCheckout(params, completedBookingsCount: 1);
      final older = cubit.applyVoucher('FIRST');
      final newer = cubit.applyVoucher('SECOND');
      second.complete(
        const Right({'final_total': 80, 'voucher_code': 'SECOND'}),
      );
      await newer;
      first.complete(const Right({'final_total': 90, 'voucher_code': 'FIRST'}));
      await older;
      expect(cubit.state.selectedVoucher?['code'], 'SECOND');
      expect(cubit.state.serverFinalTotal, 80);
    },
  );

  test('successful retry after price change completes checkout', () async {
    final params = validParams();
    var attempts = 0;
    when(
      () => bookingRepository.createBookingCheckout(
        operationId: any(named: 'operationId'),
        holdToken: any(named: 'holdToken'),
        roomRequests: any(named: 'roomRequests'),
        extraItems: any(named: 'extraItems'),
        voucherCode: any(named: 'voucherCode'),
        paymentMethod: any(named: 'paymentMethod'),
        senderWalletPhone: any(named: 'senderWalletPhone'),
        receiptUrl: any(named: 'receiptUrl'),
      ),
    ).thenAnswer(
      (_) async => ++attempts == 1
          ? const Left(
              PriceChangedFailure(
                message: 'PRICE_CHANGED',
                oldPrice: 100,
                newPrice: 120,
              ),
            )
          : const Right({
              'primary_booking_id': 'booking-retry',
              'quote': {'final_total': 120},
            }),
    );
    when(
      () => bookingRepository.watchBookingStatus('booking-retry'),
    ).thenAnswer((_) => const Stream<BookingModel>.empty());
    await cubit.processPayment(params, paymentMethod: 'cash');
    expect(cubit.state.priceChangedFailure, isNotNull);
    await cubit.processPayment(params, paymentMethod: 'cash');
    expect(cubit.state.status, CheckoutStatus.success);
    expect(cubit.state.createdBookingId, 'booking-retry');
    expect(cubit.state.priceChangedFailure, isNull);
  });

  test(
    'closing during proof upload does not emit or subscribe afterwards',
    () async {
      final params = validParams();
      final upload = Completer<String?>();
      when(
        () => bookingRepository.createBookingCheckout(
          operationId: any(named: 'operationId'),
          holdToken: any(named: 'holdToken'),
          roomRequests: any(named: 'roomRequests'),
          extraItems: any(named: 'extraItems'),
          voucherCode: any(named: 'voucherCode'),
          paymentMethod: any(named: 'paymentMethod'),
          senderWalletPhone: any(named: 'senderWalletPhone'),
          receiptUrl: any(named: 'receiptUrl'),
        ),
      ).thenAnswer(
        (_) async => const Right({'primary_booking_id': 'booking-upload'}),
      );
      when(
        () => storageService.uploadPaymentProof(
          userId: any(named: 'userId'),
          bookingId: any(named: 'bookingId'),
          file: any(named: 'file'),
        ),
      ).thenAnswer((_) => upload.future);
      final payment = cubit.processPayment(
        params,
        receiptFile: File('receipt.jpg'),
        paymentMethod: 'manual_transfer',
      );
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      upload.complete(null);
      await payment;
      verifyNever(() => bookingRepository.watchBookingStatus(any()));
    },
  );

  test(
    'keeps checkout successful when payment proof upload fails after booking creation',
    () async {
      final params = MockCheckoutParams();
      final room = MockRoomModel();
      final receipt = File('receipt.jpg');

      when(() => params.holdToken).thenReturn('hold-token');
      when(() => params.rooms).thenReturn([room]);
      when(() => params.roomsBreakdown).thenReturn(const []);
      when(() => params.playMode).thenReturn('single');
      when(() => params.extraControllers).thenReturn(0);
      when(() => params.addOns).thenReturn(const []);
      when(() => room.id).thenReturn('room-1');
      when(() => preferenceManager.userId()).thenReturn('user-1');
      when(
        () => bookingRepository.createBookingCheckout(
          operationId: any(named: 'operationId'),
          holdToken: any(named: 'holdToken'),
          roomRequests: any(named: 'roomRequests'),
          extraItems: any(named: 'extraItems'),
          voucherCode: any(named: 'voucherCode'),
          paymentMethod: any(named: 'paymentMethod'),
          senderWalletPhone: any(named: 'senderWalletPhone'),
          receiptUrl: any(named: 'receiptUrl'),
        ),
      ).thenAnswer(
        (_) async => const Right({
          'primary_booking_id': 'booking-1',
          'quote': <String, dynamic>{'final_total': 100},
        }),
      );
      when(
        () => storageService.uploadPaymentProof(
          userId: any(named: 'userId'),
          bookingId: any(named: 'bookingId'),
          file: any(named: 'file'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => bookingRepository.watchBookingStatus('booking-1'),
      ).thenAnswer((_) => const Stream<BookingModel>.empty());

      await cubit.processPayment(
        params,
        receiptFile: receipt,
        paymentMethod: 'manual_transfer',
        senderAccount: '01012345678',
      );

      expect(cubit.state.status, CheckoutStatus.success);
      expect(cubit.state.createdBookingId, 'booking-1');
      expect(cubit.state.paymentProofUploadFailed, isTrue);
      verifyNever(
        () => bookingRepository.attachBookingReceipt(
          bookingId: any(named: 'bookingId'),
          receiptPath: any(named: 'receiptPath'),
        ),
      );
    },
  );

  test(
    'processPayment ignores concurrent invocation when already in loading state',
    () async {
      final params = MockCheckoutParams();
      final room = MockRoomModel();
      when(() => params.holdToken).thenReturn('hold-token');
      when(() => params.rooms).thenReturn([room]);
      when(() => params.roomsBreakdown).thenReturn(const []);
      when(() => params.playMode).thenReturn('single');
      when(() => params.extraControllers).thenReturn(0);
      when(() => params.addOns).thenReturn(const []);
      when(() => room.id).thenReturn('room-1');
      when(() => preferenceManager.userId()).thenReturn('user-1');

      when(
        () => bookingRepository.createBookingCheckout(
          operationId: any(named: 'operationId'),
          holdToken: any(named: 'holdToken'),
          roomRequests: any(named: 'roomRequests'),
          extraItems: any(named: 'extraItems'),
          voucherCode: any(named: 'voucherCode'),
          paymentMethod: any(named: 'paymentMethod'),
          senderWalletPhone: any(named: 'senderWalletPhone'),
          receiptUrl: any(named: 'receiptUrl'),
        ),
      ).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return const Right({
          'primary_booking_id': 'booking-guard-1',
          'quote': <String, dynamic>{'final_total': 100},
        });
      });
      when(
        () => bookingRepository.watchBookingStatus('booking-guard-1'),
      ).thenAnswer((_) => const Stream<BookingModel>.empty());

      // Trigger two simultaneous payment calls
      final call1 = cubit.processPayment(params, paymentMethod: 'cash');
      final call2 = cubit.processPayment(params, paymentMethod: 'cash');

      await Future.wait([call1, call2]);

      // Exactly ONE createBookingCheckout call should be executed
      verify(
        () => bookingRepository.createBookingCheckout(
          operationId: any(named: 'operationId'),
          holdToken: any(named: 'holdToken'),
          roomRequests: any(named: 'roomRequests'),
          extraItems: any(named: 'extraItems'),
          voucherCode: any(named: 'voucherCode'),
          paymentMethod: any(named: 'paymentMethod'),
          senderWalletPhone: any(named: 'senderWalletPhone'),
          receiptUrl: any(named: 'receiptUrl'),
        ),
      ).called(1);
    },
  );
  void stubCheckoutSuccess() {
    when(
      () => bookingRepository.createBookingCheckout(
        operationId: any(named: 'operationId'),
        holdToken: any(named: 'holdToken'),
        roomRequests: any(named: 'roomRequests'),
        extraItems: any(named: 'extraItems'),
        voucherCode: any(named: 'voucherCode'),
        paymentMethod: any(named: 'paymentMethod'),
        senderWalletPhone: any(named: 'senderWalletPhone'),
        receiptUrl: any(named: 'receiptUrl'),
      ),
    ).thenAnswer((_) async => const Right({'primary_booking_id': 'created'}));
    when(
      () => bookingRepository.watchBookingStatus('created'),
    ).thenAnswer((_) => const Stream<BookingModel>.empty());
  }

  test(
    'explicit transfer confirmation overrides a changed cash selection',
    () async {
      final params = validParams();
      stubCheckoutSuccess();
      cubit.selectPaymentMethod(PaymentMethod.cash);
      await cubit.processPayment(
        params,
        paymentMethod: 'manual_transfer',
        senderAccount: 'fixture',
      );
      final calls = verify(
        () => bookingRepository.createBookingCheckout(
          operationId: any(named: 'operationId'),
          holdToken: any(named: 'holdToken'),
          roomRequests: any(named: 'roomRequests'),
          extraItems: any(named: 'extraItems'),
          voucherCode: any(named: 'voucherCode'),
          paymentMethod: captureAny(named: 'paymentMethod'),
          senderWalletPhone: any(named: 'senderWalletPhone'),
          receiptUrl: any(named: 'receiptUrl'),
        ),
      ).captured;
      expect(calls.single, 'manual_transfer');
    },
  );

  test(
    'successful checkout cannot create another booking on repeated confirmation',
    () async {
      final params = validParams();
      stubCheckoutSuccess();
      await cubit.processPayment(params, paymentMethod: 'cash');
      await cubit.processPayment(params, paymentMethod: 'cash');
      verify(
        () => bookingRepository.createBookingCheckout(
          operationId: any(named: 'operationId'),
          holdToken: any(named: 'holdToken'),
          roomRequests: any(named: 'roomRequests'),
          extraItems: any(named: 'extraItems'),
          voucherCode: any(named: 'voucherCode'),
          paymentMethod: any(named: 'paymentMethod'),
          senderWalletPhone: any(named: 'senderWalletPhone'),
          receiptUrl: any(named: 'receiptUrl'),
        ),
      ).called(1);
    },
  );

  test(
    'late quote from previous checkout is ignored while new profile check waits',
    () async {
      final first = validParams(), second = validParams();
      final lounge = MockLoungeModel();
      when(() => lounge.allowCashPayment).thenReturn(true);
      when(() => lounge.requirePrepaidFirstTime).thenReturn(false);
      for (final params in [first, second]) {
        when(() => params.lounge).thenReturn(lounge);
        when(
          () => params.holdExpiresAt,
        ).thenReturn(DateTime.now().add(const Duration(minutes: 10)));
      }
      when(() => second.holdToken).thenReturn('new-hold');
      when(
        () => bookingRepository.releaseBookingHold(any()),
      ).thenAnswer((_) async => const Right(null));
      final quote = Completer<Either<Failure, Map<String, dynamic>>>();
      when(
        () => bookingRepository.quoteBookingCheckout(
          holdToken: any(named: 'holdToken'),
          roomRequests: any(named: 'roomRequests'),
          extraItems: any(named: 'extraItems'),
          voucherCode: any(named: 'voucherCode'),
        ),
      ).thenAnswer(
        (invocation) => invocation.namedArguments[#holdToken] == 'hold-token'
            ? quote.future
            : Future.value(const Right({'final_total': 200})),
      );
      final profile = Completer<Either<Failure, int>>();
      when(
        () => profileRepository.getTotalBookingsCount(),
      ).thenAnswer((_) => profile.future);
      final oldInit = cubit.initCheckout(first, completedBookingsCount: 1);
      final newInit = cubit.initCheckout(second);
      quote.complete(const Right({'final_total': 100}));
      await oldInit;
      final staleTotal = cubit.state.serverFinalTotal;
      profile.complete(const Right(1));
      await newInit;
      expect(staleTotal, isNull);
      expect(cubit.state.serverFinalTotal, 200);
    },
  );
  test('expired hold release cannot clear a newer checkout hold', () async {
    final first = validParams(), second = validParams();
    final lounge = MockLoungeModel();
    when(() => lounge.allowCashPayment).thenReturn(true);
    when(() => lounge.requirePrepaidFirstTime).thenReturn(false);
    for (final params in [first, second]) {
      when(() => params.lounge).thenReturn(lounge);
    }
    when(
      () => first.holdExpiresAt,
    ).thenReturn(DateTime.now().add(const Duration(milliseconds: 1500)));
    when(
      () => second.holdExpiresAt,
    ).thenReturn(DateTime.now().add(const Duration(minutes: 10)));
    when(() => second.holdToken).thenReturn('replacement-hold');
    final release = Completer<Either<Failure, void>>();
    when(
      () => bookingRepository.releaseBookingHold('hold-token'),
    ).thenAnswer((_) => release.future);
    when(
      () => bookingRepository.releaseBookingHold('replacement-hold'),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => bookingRepository.quoteBookingCheckout(
        holdToken: any(named: 'holdToken'),
        roomRequests: any(named: 'roomRequests'),
        extraItems: any(named: 'extraItems'),
        voucherCode: any(named: 'voucherCode'),
      ),
    ).thenAnswer((_) async => const Right({'final_total': 100}));
    await cubit.initCheckout(first, completedBookingsCount: 1);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    verify(() => bookingRepository.releaseBookingHold('hold-token')).called(1);
    await cubit.initCheckout(second, completedBookingsCount: 1);
    release.complete(const Right(null));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.holdToken, 'replacement-hold');
    expect(cubit.state.isHoldExpired, isFalse);
  });

  test(
    'lost checkout response remains pending and recovers after restart',
    () async {
      final params = validParams();
      final saved = <String, String>{};
      when(() => preferenceManager.getValue(any())).thenAnswer(
        (call) => saved[call.positionalArguments[0] as String] ?? '',
      );
      when(() => preferenceManager.saveValue(any(), any())).thenAnswer((
        call,
      ) async {
        saved[call.positionalArguments[0] as String] =
            call.positionalArguments[1] as String;
      });
      when(() => preferenceManager.clearValue(any())).thenAnswer((call) async {
        saved.remove(call.positionalArguments[0] as String);
      });
      when(
        () => bookingRepository.createBookingCheckout(
          operationId: any(named: 'operationId'),
          holdToken: any(named: 'holdToken'),
          roomRequests: any(named: 'roomRequests'),
          extraItems: any(named: 'extraItems'),
          voucherCode: any(named: 'voucherCode'),
          paymentMethod: any(named: 'paymentMethod'),
          senderWalletPhone: any(named: 'senderWalletPhone'),
          receiptUrl: any(named: 'receiptUrl'),
        ),
      ).thenAnswer((_) async => const Left(NetworkFailure('lost response')));
      var lookups = 0;
      when(() => bookingRepository.recoverBookingCheckout(any())).thenAnswer(
        (_) async => ++lookups == 1
            ? const Right(null)
            : const Right({'primary_booking_id': 'recovered-booking'}),
      );
      when(
        () => bookingRepository.watchBookingStatus('recovered-booking'),
      ).thenAnswer((_) => const Stream<BookingModel>.empty());

      await cubit.processPayment(params, paymentMethod: 'cash');
      expect(cubit.state.status, CheckoutStatus.pending);
      expect(saved, hasLength(1));
      await cubit.close();
      cubit = CheckoutCubit(
        bookingRepository,
        profileRepository,
        preferenceManager: preferenceManager,
        storageService: storageService,
      );
      await cubit.initCheckout(params);
      expect(cubit.state.status, CheckoutStatus.success);
      expect(cubit.state.createdBookingId, 'recovered-booking');
      expect(saved, isEmpty);
      verify(
        () => bookingRepository.createBookingCheckout(
          operationId: any(named: 'operationId'),
          holdToken: any(named: 'holdToken'),
          roomRequests: any(named: 'roomRequests'),
          extraItems: any(named: 'extraItems'),
          voucherCode: any(named: 'voucherCode'),
          paymentMethod: any(named: 'paymentMethod'),
          senderWalletPhone: any(named: 'senderWalletPhone'),
          receiptUrl: any(named: 'receiptUrl'),
        ),
      ).called(1);
    },
  );
}
