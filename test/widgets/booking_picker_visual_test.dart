import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/room_card/room_card.dart';
import 'package:playspot/features/booking/presentation/booking_cubit.dart';
import 'package:playspot/features/booking/presentation/booking_state.dart';
import 'package:playspot/features/booking/presentation/widgets/time_slot_grid.dart';
import 'package:playspot/features/booking/presentation/widgets/time_slot_tile.dart';
import 'package:playspot/features/booking/domain/entities/room_slot_price.dart';
import '../support/local_translations_loader.dart';
import '../support/mock_booking_cubit.dart';
import '../support/mock_lounge_details_cubit.dart';

void main() {
  registerFallbackValue(const TimeOfDay(hour: 10, minute: 0));
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();
  final room = RoomModel(
    id: 'r',
    loungeId: 'l',
    nameAr: 'غرفة PlayStation 5',
    nameEn: 'PlayStation 5 room',
    activityNames: const ['PS5'],
    maxCapacity: 4,
    hourlyRateSingle: 100,
    hourlyRateMulti: 150,
    isAvailable: true,
    images: const [],
    featuresAr: const [],
    featuresEn: const [],
  );
  final lounge = LoungeModel(
    id: 'l',
    name: 'PlaySpot',
    imageUrl: '',
    rating: 4.5,
    distance: 1,
    pricePerHour: 100,
    isOpen: true,
    openingTime: '10:00',
    closingTime: '12:00',
  );
  final loungeCubit = MockLoungeDetailsCubit();
  final bookingCubit = MockBookingCubit();
  when(() => loungeCubit.state).thenReturn(
    LoungeDetailsState(
      status: LoungeDetailsStatus.success,
      lounge: lounge,
      rooms: [room],
    ),
  );
  when(() => bookingCubit.state).thenReturn(
    BookingState(
      status: BookingStatus.success,
      selectedDate: now.add(const Duration(days: 1)),
      bookedTimeSlots: const [TimeOfDay(hour: 10, minute: 15)],
      slotPrices: const [
        RoomSlotPrice(
          slotStart: '10:00:00',
          slotEnd: '10:15:00',
          isAvailable: true,
          hourlyRate: 123.75,
          ruleType: 'standard',
          isPeak: false,
        ),
      ],
    ),
  );
  when(() => bookingCubit.selectStartTime(any())).thenAnswer((_) {});
  final captureKey = GlobalKey();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final font = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal/Tajawal-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final english = FontLoader('Orbitron')
      ..addFont(rootBundle.load('assets/fonts/Orbitron/Orbitron-Regular.ttf'));
    await english.load();
  });

  Future<void> mount(
    WidgetTester tester,
    double width,
    String locale,
    double scale,
  ) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      EasyLocalization(
        key: ValueKey('$width-$locale-$scale'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        startLocale: Locale(locale),
        fallbackLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                  key: captureKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: ThemeData.dark().copyWith(
                scaffoldBackgroundColor: AppColors.scaffoldBackground,
                textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: 'Tajawal',
                ),
              ),
              home: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SizedBox(
                    child: MultiBlocProvider(
                      providers: [
                        BlocProvider<LoungeDetailsCubit>.value(
                          value: loungeCubit,
                        ),
                        BlocProvider<BookingCubit>.value(value: bookingCubit),
                      ],
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            RoomCard(room: room),
                            TimeSlotGrid(lounge: lounge),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    await tester.pump();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    final directory = Platform.environment['PLAYSPOT_SCREENSHOT_DIR'];
    if (directory == null) return;
    final boundary =
        captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [360.0, 600.0, 768.0, 1024.0, 1440.0]) {
    for (final locale in ['ar', 'en']) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('picker $width $locale text=$scale', (tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await mount(tester, width, locale, scale);
          expect(tester.takeException(), isNull);
          expect(find.byType(RoomCard), findsOneWidget);
          expect(find.byType(TimeSlotGrid), findsOneWidget);
          verifyNever(() => bookingCubit.selectStartTime(any()));
          await screenshot(tester, 'picker-${width.toInt()}-$locale-$scale');
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
  testWidgets('time is selected only after an explicit tap', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, 360, 'ar', 1);
    verifyNever(() => bookingCubit.selectStartTime(any()));
    await tester.ensureVisible(find.byType(TimeSlotTile).first);
    await tester.tap(find.byType(TimeSlotTile).first);
    await tester.pump();
    verify(
      () => bookingCubit.selectStartTime(const TimeOfDay(hour: 10, minute: 0)),
    ).called(1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
