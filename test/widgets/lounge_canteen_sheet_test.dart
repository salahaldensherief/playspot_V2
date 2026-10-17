import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/features/booking/domain/repositories/booking_repository.dart';
import 'package:playspot/features/lounge_details/domain/repositories/lounge_details_repository.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';
import 'package:playspot/features/active_session/data/models/canteen_combo_model.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/canteen_menu_item.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/widgets/lounge_canteen_section.dart';
import 'package:playspot/features/tournaments/domain/usecases/get_tournaments_usecase.dart';
import '../support/local_translations_loader.dart';
import '../support/mock_home_repository.dart';

class _Details extends Mock implements LoungeDetailsRepository {}

class _Bookings extends Mock implements BookingRepository {}

class _Tournaments extends Mock implements GetTournamentsUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoungeDetailsCubit cubit;
  late _Details details;
  final capture = GlobalKey();
  const extras = [
    ExtraModel(
      id: 'water',
      name: 'Water',
      nameAr: 'مياه',
      nameEn: 'Water',
      price: 18,
      category: 'drinks',
    ),
    ExtraModel(
      id: 'snack',
      name: 'Crisps',
      nameAr: 'رقائق البطاطس',
      nameEn: 'Crisps',
      price: 29,
      category: 'snacks',
      isAvailable: false,
    ),
  ];
  final combo = CanteenComboModel.fromJson({
    'id': 'friends',
    'name_ar': 'باقة تسالي الأصدقاء',
    'name_en': 'Friends snack combo',
    'description_ar': 'مياه ورقائق بطاطس',
    'description_en': 'Water and crisps',
    'price': 84.6,
    'separate_items_price': 94,
    'savings': 9.4,
    'is_available': true,
    'items': [
      {
        'extra_id': 'water',
        'name_ar': 'مياه',
        'name_en': 'Water',
        'price': 18,
        'quantity': 2,
      },
    ],
  });
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
    details = _Details();
    cubit = LoungeDetailsCubit(
      details,
      MockHomeRepository(),
      _Bookings(),
      _Tournaments(),
    );
    cubit.emit(
      LoungeDetailsState(
        status: LoungeDetailsStatus.success,
        extras: extras,
        combos: [combo],
      ),
    );
  });
  tearDown(() async => cubit.close());
  Future<void> mount(
    WidgetTester tester,
    String language, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        key: ValueKey('$language-$width-$scale'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        startLocale: Locale(language),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: ThemeData.dark().copyWith(
                scaffoldBackgroundColor: AppColors.scaffoldBackground,
                textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: language == 'ar' ? 'Tajawal' : 'Orbitron',
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
              home: BlocProvider.value(
                value: cubit,
                child: const Scaffold(
                  body: CustomScrollView(slivers: [LoungeCanteenSection()]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String language) async {
    await tester.tap(
      find.text(
        language == 'ar' ? 'استعراض القائمة والعروض' : 'Browse menu & offers',
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    const output = String.fromEnvironment('CANTEEN_CAPTURE_DIR');
    if (output.isEmpty) return;
    await tester.runAsync(() async {
      final boundary =
          capture.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Missing capture boundary');
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Missing image bytes');
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final language in ['ar', 'en']) {
    testWidgets(
      'menu $language preserves quantity and cubit after sheet dismissal',
      (tester) async {
        await mount(tester, language);
        await open(tester, language);
        await tester.tap(
          find
              .byTooltip(
                language == 'ar' ? 'زيادة الكمية' : 'Increase quantity',
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(cubit.state.selectedExtras['water'], 1);
        await screenshot(tester, 'menu-$language');
        await tester.tap(find.text(language == 'ar' ? 'تم' : 'Done'));
        await tester.pumpAndSettle();
        expect(cubit.isClosed, isFalse);
        expect(cubit.state.selectedExtras['water'], 1);
        await open(tester, language);
        expect(cubit.state.selectedExtras['water'], 1);
        verifyNoMoreInteractions(details);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('combo $language shows contents exact price and savings', (
      tester,
    ) async {
      await mount(tester, language);
      await open(tester, language);
      await tester.tap(
        find.text(language == 'ar' ? 'عروض الكومبو' : 'Combo offers').first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          language == 'ar' ? 'باقة تسالي الأصدقاء' : 'Friends snack combo',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('84.60'), findsOneWidget);
      expect(find.textContaining('9.40'), findsOneWidget);
      expect(find.textContaining('{}'), findsNothing);
      expect(cubit.state.selectedExtras, isEmpty);
      await screenshot(tester, 'offers-$language');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'unavailable item cannot be added; category filter is reversible',
    (tester) async {
      await mount(tester, 'en');
      await open(tester, 'en');
      await tester.tap(find.text('Snacks'));
      await tester.pumpAndSettle();
      expect(find.byType(CanteenMenuItem), findsOneWidget);
      expect(find.text('Currently unavailable'), findsOneWidget);
      final add = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Increase quantity',
        ),
      );
      expect(add.onPressed, isNull);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.byType(CanteenMenuItem), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('narrow Arabic sheet supports large text without overflow', (
    tester,
  ) async {
    await mount(tester, 'ar', width: 320, scale: 1.8);
    await open(tester, 'ar');
    expect(tester.takeException(), isNull);
    await screenshot(tester, 'menu-ar-large-text');
  });
  testWidgets('empty menu is explicit and does not open an empty sheet', (
    tester,
  ) async {
    cubit.emit(const LoungeDetailsState(status: LoungeDetailsStatus.success));
    await mount(tester, 'en');
    expect(
      find.text('The canteen menu is currently unavailable.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
