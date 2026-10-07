import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/helper/screens_size_handler.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/lounge_details/data/models/room_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_screen.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/lounge_details_content.dart';
import 'package:playspot/art_core/widgets/buttons/app_button.dart';
import 'package:playspot/features/lounge_details/domain/entities/lounge_operating_status.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/lounge_gallery_action.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/photo_indicator.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/space_type_selector.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/lounge_hero_header.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/lounge_technical_issue_banner.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/lounge_closed_banner.dart';
import 'package:playspot/art_core/widgets/layout/full_screen_gallery.dart';
import '../support/local_translations_loader.dart';
import '../support/mock_locale_cubit.dart';
import '../support/mock_lounge_details_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final room = RoomModel.fromJson({
    'id': 'r',
    'lounge_id': 'l',
    'name_ar': 'غرفة PlayStation 5',
    'name_en': 'PlayStation 5 room',
    'activity_names': ['PS5'],
    'space_type_slug': 'standard_room',
    'max_capacity': 4,
    'hourly_rate_single': 100,
    'hourly_rate_multi': 150,
    'controllers_count': 2,
    'screen_size': '50"',
    'features_ar': ['تكييف', 'عزل صوتي'],
    'features_en': ['Air conditioning', 'Sound insulation'],
  });
  final busy = RoomModel.fromJson({
    'id': 'busy',
    'lounge_id': 'l',
    'name_ar': 'غرفة VR',
    'name_en': 'VR room',
    'activity_names': ['VR'],
    'space_type_slug': 'vip_room',
    'is_available': false,
    'status': 'occupied',
    'hourly_rate_single': 180,
  });
  final lounge = LoungeModel.fromJson({
    'id': 'l',
    'name': 'PlaySpot · Cairo',
    'image_url': '',
    'rating': 4.6,
    'total_reviews': 126,
    'distance_km': 3.974644,
    'latitude': 30.0444,
    'longitude': 31.2357,
    'location': 'القاهرة',
    'address': 'شارع التجمع الخامس، بجوار مركز الألعاب',
    'city': 'Cairo',
    'description_ar':
        'اختار الغرفة المناسبة لك، وقارن التجهيزات والسعر قبل ما تحجز.',
    'description_en':
        'Choose your room and compare its equipment and price before booking.',
    'opening_time': '10:00:00',
    'closing_time': '02:00:00',
    'wallet_number': 'fixture-wallet',
    'instapay_handle': 'fixture-handle',
    'require_prepaid_first_time': true,
  });
  final initial = LoungeDetailsState(
    status: LoungeDetailsStatus.success,
    lounge: lounge,
    rooms: [room, busy],
    selectedDate: DateTime.now(),
    operatingStatus: const LoungeOperatingStatus(
      status: 'open',
      canBookOnline: true,
    ),
  );
  late MockLoungeDetailsCubit cubit;
  late MockLocaleCubit localeCubit;
  late StreamController<LoungeDetailsState> states;
  final capture = GlobalKey();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final pair in [
      ['Tajawal', 'assets/fonts/Tajawal/Tajawal-Regular.ttf'],
      ['Orbitron', 'assets/fonts/Orbitron/Orbitron-Regular.ttf'],
      ['MaterialIcons', 'fonts/MaterialIcons-Regular.otf'],
    ]) {
      await (FontLoader(pair[0])..addFont(rootBundle.load(pair[1]))).load();
    }
  });
  setUp(() {
    cubit = MockLoungeDetailsCubit();
    localeCubit = MockLocaleCubit();
    states = StreamController<LoungeDetailsState>.broadcast();
    whenListen(cubit, states.stream, initialState: initial);
    when(() => localeCubit.state).thenReturn(const Locale('ar'));
    when(() => cubit.init(lounge)).thenAnswer((_) {});
  });
  tearDown(() async {
    await states.close();
  });

  Future<void> mount(
    WidgetTester tester,
    double width,
    String locale,
    double scale,
  ) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    when(() => localeCubit.state).thenReturn(Locale(locale));
    await tester.pumpWidget(
      EasyLocalization(
        key: ValueKey('$width-$locale-$scale'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        startLocale: Locale(locale),
        fallbackLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: MediaQuery(
          data: MediaQueryData.fromView(tester.view),
          child: Builder(
            builder: (context) => ScreenUtilInit(
              designSize: DeviceTypeHelper.getSize(context),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (context, child) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: ThemeData.dark().copyWith(
                  scaffoldBackgroundColor: AppColors.scaffoldBackground,
                  textTheme: ThemeData.dark().textTheme.apply(
                    fontFamily: locale == 'ar' ? 'Tajawal' : 'Orbitron',
                  ),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(
                    key: capture,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
                home: BlocProvider<LocaleCubit>.value(
                  value: localeCubit,
                  child: BlocProvider<LoungeDetailsCubit>.value(
                    value: cubit,
                    child: LoungeDetailsScreen(lounge: lounge),
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
  }

  void expectClean(WidgetTester tester) {
    final exception = tester.takeException();
    expect(exception, isNull, reason: exception?.toString());
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    final directory = Platform.environment['PLAYSPOT_SCREENSHOT_DIR'];
    if (directory == null) return;
    final boundary = capture.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('Missing capture boundary');
    }
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 1);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Missing PNG bytes');
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
      picture.dispose();
    });
  }

  for (final locale in ['ar', 'en']) {
    testWidgets('photo button expands its label and contracts without overflow $locale', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, 360, locale, 1.6);
      final photos = LoungeModel.fromJson({
        ...lounge.toJson(),
        'image_url': 'assets/images/splash_logo.png',
        'images': ['assets/images/vodafone_cash_logo.png'],
      });
      states.add(initial.copyWith(lounge: photos));
      await tester.pump();
      await tester.pump();
      final indicator = find.byType(PhotoIndicator);
      final collapsedWidth = tester.getSize(indicator).width;
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text(AppStrings.viewPhotos.tr()), findsOneWidget);
      expect(tester.getSize(indicator).width, greaterThan(collapsedWidth));
      expectClean(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text(AppStrings.viewPhotos.tr()), findsNothing);
      expect(tester.getSize(indicator).width, closeTo(collapsedWidth, 1));
      expectClean(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('private rooms have a localized selectable space type', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, 360, 'ar', 1);
    final privateRoom = RoomModel.fromJson({...room.toJson(), 'space_type_slug': 'private'});
    states.add(initial.copyWith(rooms: [privateRoom]));
    await tester.pumpAndSettle();
    final controller = tester.widget<LoungeDetailsContent>(find.byType(LoungeDetailsContent)).controller;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expectClean(tester);
    final label = find.descendant(of: find.byType(SpaceTypeSelector), matching: find.text('room_private'.tr()));
    expect(label, findsOneWidget);
    await tester.ensureVisible(label.first);
    await tester.tap(label.first);
    verify(() => cubit.setSpaceType('private')).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('gallery action is on the photo and absent from the collapsed app bar', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, 360, 'ar', 1);
    final photos = LoungeModel.fromJson({
      ...lounge.toJson(),
      'image_url': 'assets/images/splash_logo.png',
      'images': ['assets/images/vodafone_cash_logo.png'],
    });
    states.add(initial.copyWith(lounge: photos));
    await tester.pumpAndSettle();
    final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(bar.actions, isNull);
    final background =
        (bar.flexibleSpace as FlexibleSpaceBar).background as Semantics;
    final gesture = background.child! as GestureDetector;
    expect(gesture.onTap, isNotNull);
    expect(find.descendant(of: find.byType(LoungeHeroHeader), matching: find.byType(LoungeGalleryAction)), findsOneWidget);
    final photoButton = find.descendant(of: find.byType(LoungeGalleryAction), matching: find.byType(InkWell)).first;
    await tester.tap(photoButton);
    await tester.pumpAndSettle();
    expect(find.byType(FullScreenGallery), findsOneWidget);
    expect(
      tester.widget<FullScreenGallery>(find.byType(FullScreenGallery)).images,
      photos.galleryImages,
    );
    Navigator.of(tester.element(find.byType(FullScreenGallery))).pop();
    await tester.pumpAndSettle();
    final controller = tester
        .widget<LoungeDetailsContent>(find.byType(LoungeDetailsContent))
        .controller;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(
      find
          .descendant(
            of: find.byType(LoungeGalleryAction),
            matching: find.byType(InkWell),
          )
          .hitTestable(),
      findsNothing,
    );
    expectClean(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('compact disclosures retain address, hours and payment information', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, 360, 'ar', 1.6);
    final visit = find.text('lounge_visit_section'.tr());
    await tester.ensureVisible(visit);
    await tester.tap(visit);
    await tester.pumpAndSettle();
    expect(find.text(lounge.address!), findsOneWidget);
    final payment = find.text('lounge_payment_section'.tr());
    await tester.ensureVisible(payment);
    await tester.tap(payment);
    await tester.pumpAndSettle();
    expect(find.text('lounge_first_booking_prepaid'.tr()), findsOneWidget);
    expectClean(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [360.0, 600.0, 768.0, 1024.0, 1440.0]) {
    for (final locale in ['ar', 'en']) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('lounge page $width $locale scale=$scale', (tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await mount(tester, width, locale, scale);
          expectClean(tester);
          expect(
            Directionality.of(
              tester.element(find.byType(LoungeDetailsContent)),
            ),
            locale == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          );
          await screenshot(
            tester,
            'lounge-${width.toInt()}-$locale-$scale-overview',
          );
          final controller = tester
              .widget<LoungeDetailsContent>(find.byType(LoungeDetailsContent))
              .controller;
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expectClean(tester);
          expect(find.byType(BackButtonWidget).hitTestable(), findsOneWidget);
          await screenshot(
            tester,
            'lounge-${width.toInt()}-$locale-$scale-rooms',
          );
          final card = find.byKey(const ValueKey('busy'));
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: card,
              matching: find.text(locale == 'ar' ? 'غرفة VR' : 'VR room'),
            ),
          );
          await tester.pumpAndSettle();
          expectClean(tester);
          await screenshot(
            tester,
            'lounge-${width.toInt()}-$locale-$scale-busy-expanded',
          );
          verifyNever(() => cubit.toggleRoomSelection('busy'));
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  for (final width in [360.0, 600.0, 768.0, 1024.0, 1440.0]) {
    for (final locale in ['ar', 'en']) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
          'closed lounge retains room comparison $width $locale scale=$scale',
          (tester) async {
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await mount(tester, width, locale, scale);
            final closed = LoungeModel.fromJson({
              ...lounge.toJson(),
              'is_open': false,
            });
            states.add(
              initial.copyWith(
                lounge: closed,
                operatingStatus: const LoungeOperatingStatus(
                  status: 'closed',
                  canBookOnline: false,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(LoungeClosedBanner), findsOneWidget);
            expectClean(tester);
            await screenshot(
              tester,
              'lounge-closed-${width.toInt()}-$locale-$scale-overview',
            );
            final controller = tester
                .widget<LoungeDetailsContent>(find.byType(LoungeDetailsContent))
                .controller;
            controller.jumpTo(controller.position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('busy')), findsOneWidget);
            expect(find.byKey(const ValueKey('r')), findsOneWidget);
            expectClean(tester);
            await screenshot(
              tester,
              'lounge-closed-${width.toInt()}-$locale-$scale-rooms',
            );
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  for (final width in [360.0, 600.0, 768.0, 1024.0, 1440.0]) {
    for (final locale in ['ar', 'en']) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
          'technical issue lounge displays warning and dialer $width $locale scale=$scale',
          (tester) async {
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await mount(tester, width, locale, scale);
            final techState = initial.copyWith(
              operatingStatus: const LoungeOperatingStatus(
                status: 'technical_issue',
                canBookOnline: false,
                contactPhone: '01012345678',
              ),
            );
            states.add(techState);
            await tester.pumpAndSettle();
            expectClean(tester);
            expect(find.byType(LoungeTechnicalIssueBanner), findsOneWidget);
            await screenshot(
              tester,
              'lounge-technical-issue-${width.toInt()}-$locale-$scale-overview',
            );
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  testWidgets('technical issue lounge without phone hides call button', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, 360, 'ar', 1.0);
    final techNoPhone = initial.copyWith(
      operatingStatus: const LoungeOperatingStatus(
        status: 'technical_issue',
        canBookOnline: false,
        contactPhone: null,
      ),
    );
    states.add(techNoPhone);
    await tester.pumpAndSettle();
    expectClean(tester);
    expect(find.byType(LoungeTechnicalIssueBanner), findsOneWidget);
    expect(find.text('lounge_technical_issue'.tr()), findsOneWidget);
    expect(find.text('technical_issue'.tr()), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LoungeTechnicalIssueBanner),
        matching: find.byType(AppButton),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'room selection changes do not rebuild the lounge page or its overview',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, 360, 'ar', 1);
      final controller = tester
          .widget<LoungeDetailsContent>(find.byType(LoungeDetailsContent))
          .controller;
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final counts = <String, int>{};
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        counts.update(
          element.widget.runtimeType.toString(),
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      };
      final watch = Stopwatch()..start();
      try {
        for (var i = 0; i < 20; i++) {
          states.add(initial.copyWith(selectedRoomIds: i.isEven ? {'r'} : {}));
          await tester.pumpAndSettle();
        }
      } finally {
        debugOnRebuildDirtyWidget = previous;
        watch.stop();
      }
      expect(counts['LoungeDetailsScreen'] ?? 0, 0);
      expect(counts['LoungeDetailsContent'] ?? 0, 0);
      expect(counts['LoungeInfoSection'] ?? 0, 0);
      final directory = Platform.environment['PLAYSPOT_SCREENSHOT_DIR'];
      if (directory != null) {
        File('$directory/rebuild-measurement.json').writeAsStringSync(
          jsonEncode({
            'mode':
                'Flutter widget test/debug on Windows; synthetic data; not phone GPU timings',
            'selectionChanges': 20,
            'hostElapsedMicroseconds': watch.elapsedMicroseconds,
            'builds': counts,
          }),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
