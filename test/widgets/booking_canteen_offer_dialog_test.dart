import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/features/booking/data/models/booking_params.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/domain/entities/lounge_operating_status.dart';
import 'package:playspot/features/lounge_details/domain/repositories/lounge_details_repository.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/booking_canteen_offer_dialog.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/lounge_details_bottom_bar.dart';
import 'package:playspot/features/tournaments/domain/usecases/get_tournaments_usecase.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/local_translations_loader.dart';
import '../support/mock_home_repository.dart';

class _Details extends Mock implements LoungeDetailsRepository {}

class _Bookings extends Mock implements BookingRepository {}

class _Tournaments extends Mock implements GetTournamentsUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final lounge = LoungeModel.fromJson({'id': 'lounge'});
  final room = RoomModel.fromJson({'id': 'room', 'is_available': true});
  const water = ExtraModel(
    id: 'water',
    name: 'Water',
    nameAr: 'مياه',
    nameEn: 'Water',
    price: 18,
    category: 'drinks',
  );
  late LoungeDetailsCubit cubit;
  late _Details details;
  late GoRouter router;
  BookingDetailsParams? destination;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() {
    destination = null;
    details = _Details();
    when(
      () => details.getExtras('lounge', forceRefresh: true),
    ).thenAnswer((_) async => const Right([water]));
    cubit = LoungeDetailsCubit(
      details,
      MockHomeRepository(),
      _Bookings(),
      _Tournaments(),
    );
    cubit.emit(
      LoungeDetailsState(
        status: LoungeDetailsStatus.success,
        lounge: lounge,
        rooms: [room],
        selectedRoomIds: const {'room'},
        selectedDate: DateTime(2026, 10, 20),
        operatingStatus: const LoungeOperatingStatus(
          status: 'open',
          canBookOnline: true,
        ),
        extras: const [water],
      ),
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider.value(
            value: cubit,
            child: Scaffold(
              body: Stack(children: [LoungeDetailsBottomBar(lounge: lounge)]),
            ),
          ),
        ),
        GoRoute(
          path: RouterKeys.booking,
          name: RouterKeys.booking,
          builder: (context, state) {
            destination = state.extra as BookingDetailsParams;
            return const Scaffold(body: Text('booking destination'));
          },
        ),
      ],
    );
  });
  tearDown(() async {
    router.dispose();
    await cubit.close();
  });

  Future<void> mount(
    WidgetTester tester,
    String language, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('ar'), Locale('en')],
        startLocale: Locale(language),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp.router(
              routerConfig: router,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['ar', 'en']) {
    testWidgets('declining canteen clears extras and continues in $language', (
      tester,
    ) async {
      cubit.updateExtraQuantity(water.id, 1);
      await mount(tester, language);
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(find.byType(BookingCanteenOfferDialog), findsOneWidget);
      expect(find.text(language == 'ar' ? 'مياه' : 'Water'), findsOneWidget);
      await tester.tap(
        find.text(
          language == 'ar' ? 'كمّل من غير طلب' : 'Continue without snacks',
        ),
      );
      await tester.pumpAndSettle();
      expect(destination?.extras, isEmpty);
      expect(cubit.state.selectedExtras, isEmpty);
      expect(find.text('booking destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selected canteen item reaches booking parameters', (
    tester,
  ) async {
    await mount(tester, 'en');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(cubit.state.selectedExtras['water'], 1);
    await tester.tap(find.text('Add to booking and continue'));
    await tester.pumpAndSettle();
    expect(destination?.extras, [
      {'id': 'water', 'name': 'Water', 'price': 18.0, 'quantity': 1},
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing the offer does not start a booking', (tester) async {
    await mount(tester, 'en');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(destination, isNull);
    expect(find.byType(BookingCanteenOfferDialog), findsNothing);
  });

  testWidgets('lounge without live canteen items skips the offer', (
    tester,
  ) async {
    when(
      () => details.getExtras('lounge', forceRefresh: true),
    ).thenAnswer((_) async => const Right([]));
    cubit.updateExtraQuantity(water.id, 1);
    await mount(tester, 'en');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.byType(BookingCanteenOfferDialog), findsNothing);
    expect(destination?.extras, isEmpty);
    expect(cubit.state.selectedExtras, isEmpty);
    expect(find.text('booking destination'), findsOneWidget);
  });

  testWidgets('failed catalogue check keeps booking in place for retry', (
    tester,
  ) async {
    when(
      () => details.getExtras('lounge', forceRefresh: true),
    ).thenAnswer((_) async => const Left(ServerFailure('Offline')));
    await mount(tester, 'en');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.byType(BookingCanteenOfferDialog), findsNothing);
    expect(destination, isNull);
    expect(
      find.text('Could not refresh the details. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('offer fits a narrow phone in Arabic', (tester) async {
    await mount(tester, 'ar', size: const Size(320, 640));
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.byType(BookingCanteenOfferDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
