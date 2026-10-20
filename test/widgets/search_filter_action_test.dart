import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/features/search/presentation/search_cubit.dart';
import 'package:playspot/features/search/presentation/search_screen.dart';
import 'package:playspot/features/search/presentation/search_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/local_translations_loader.dart';

class _SearchCubit extends MockCubit<SearchState> implements SearchCubit {}

void main() {
  testWidgets('search filter action clears only after a filter is active', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final cubit = _SearchCubit();
    when(() => cubit.state).thenReturn(const SearchState());
    when(
      () => cubit.search(
        query: any(named: 'query'),
        isOpenOnly: any(named: 'isOpenOnly'),
        sortType: any(named: 'sortType'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/lang',
        assetLoader: const LocalTranslationsLoader(),
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, _) => BlocProvider<SearchCubit>.value(
            value: cubit,
            child: MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const SearchScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(AppStrings.clearSearchFilters.tr()), findsNothing);
    await tester.tap(find.text(AppStrings.openNow.tr()));
    await tester.pump();
    verify(
      () => cubit.search(query: '', isOpenOnly: true, sortType: 'nearest'),
    ).called(1);

    await tester.tap(find.byTooltip(AppStrings.clearSearchFilters.tr()));
    await tester.pump();
    verify(
      () => cubit.search(query: '', isOpenOnly: false, sortType: 'nearest'),
    ).called(1);
    expect(find.byTooltip(AppStrings.clearSearchFilters.tr()), findsNothing);
  });
}
