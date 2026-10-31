import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/tournaments/presentation/tournaments_feed/tournaments_feed_cubit.dart';
import 'package:playspot/features/tournaments/presentation/tournaments_feed/tournaments_feed_screen.dart';
import 'package:playspot/features/tournaments/presentation/tournaments_feed/tournaments_feed_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/local_translations_loader.dart';

class _FeedCubit extends MockCubit<TournamentsFeedState>
    implements TournamentsFeedCubit {}

void main() {
  testWidgets(
    'status menu filters tournaments without occupying a second row',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      final cubit = _FeedCubit();
      when(() => cubit.state).thenReturn(const TournamentsFeedState());
      when(() => cubit.loadTournaments()).thenAnswer((_) async {});
      when(() => cubit.filterByStatus(any())).thenReturn(null);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('ar')],
          startLocale: const Locale('en'),
          saveLocale: false,
          path: 'assets/lang',
          assetLoader: const LocalTranslationsLoader(),
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, _) => BlocProvider<TournamentsFeedCubit>.value(
              value: cubit,
              child: MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: const TournamentsFeedScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(AppStrings.filterByStatus.tr()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.registrationOpen.tr()).last);
      await tester.pumpAndSettle();

      verify(() => cubit.filterByStatus('registration_open')).called(1);
      expect(tester.takeException(), isNull);
    },
  );
}
