import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/services/supabase_storage_service.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/checkout/presentation/checkout_cubit.dart';
import 'package:playspot/features/checkout/presentation/checkout_state.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/my_bookings/data/models/booking_model.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';

class MockBookingRepository extends Mock implements BookingRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockPreferenceManager extends Mock implements PreferenceManager {}

class MockStorageService extends Mock implements StorageService {}

class MockCheckoutParams extends Mock implements CheckoutParams {}

class MockRoomModel extends Mock implements RoomModel {}

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
}
