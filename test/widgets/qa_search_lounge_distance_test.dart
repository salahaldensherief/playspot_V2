import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/art_core/widgets/cards/search_lounge_card.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

import '../support/local_translations_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final language in ['en', 'ar']) {
    for (final available in [false, true]) {
      testWidgets('search distance $language available=$available', (
        tester,
      ) async {
        final lounge = LoungeModel.fromJson({
          'id': 'fixture',
          'name': 'Orbit',
          'rating': 4.7,
          'price_per_hour': 145,
          'available_rooms': 6,
          'distance_km': available ? 0.25 : null,
          'distance_is_approximate': available,
        });
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('ar')],
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
                  home: Scaffold(body: SearchLoungeCard(lounge: lounge)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Infinity'), findsNothing);
        expect(find.textContaining('NaN'), findsNothing);
        expect(
          find.byIcon(Icons.location_on_outlined),
          available ? findsOneWidget : findsNothing,
        );
        if (available) {
          expect(
            find.text(language == 'ar' ? '≈ 250 م' : '≈ 250 m'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
