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
