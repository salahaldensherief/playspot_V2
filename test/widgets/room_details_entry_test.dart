import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/presentation/locale_cubit.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/lounge_details/domain/repositories/lounge_details_repository.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/room_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/local_translations_loader.dart';

class _RoomRepository extends Mock implements LoungeDetailsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  tearDown(() async => sl.reset());

  testWidgets('missing linked room shows retry and survives leaving the page', (
    tester,
  ) async {
    final repository = _RoomRepository();
    var attempts = 0;
    when(() => repository.getRoomById('missing')).thenAnswer((_) async {
      attempts++;
      return const Right(null);
    });
    sl.registerSingleton<LoungeDetailsRepository>(repository);
    final localeCubit = LocaleCubit();
    addTearDown(localeCubit.close);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('ar'), Locale('en')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => BlocProvider<LocaleCubit>.value(
            value: localeCubit,
            child: MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const RoomDetailsScreen(roomId: 'missing'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.roomNotFound.tr()), findsOneWidget);
    expect(find.text(AppStrings.retry.tr()), findsOneWidget);

    await tester.tap(find.text(AppStrings.retry.tr()));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
