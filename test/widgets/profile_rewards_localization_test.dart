import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playspot/features/profile/presentation/profile/profile_cubit.dart';
import 'package:playspot/features/profile/presentation/profile/profile_state.dart';
import 'package:playspot/features/profile/presentation/profile/my_vouchers_screen.dart';
import 'package:playspot/features/profile/presentation/profile/profile_reward_labels.dart';
import '../support/local_translations_loader.dart';

class _Profile extends MockCubit<ProfileState> implements ProfileCubit {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  for (final locale in ['ar', 'en']) {
    testWidgets(
      'voucher rewards, expiry and history labels translate in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cubit = _Profile();
        final initial = ProfileState(
          status: ProfileStatus.success,
          myVouchers: [
            {
              'status': 'active',
              'code': 'TEST',
              'reward_type': 'free_hour',
              'expires_at': DateTime.now()
                  .add(const Duration(days: 3))
                  .toIso8601String(),
            },
            {
              'status': 'active',
              'code': 'MISSING-DATE',
              'reward_type': 'discount',
              'reward_value': 12.5,
            },
          ],
        );
        whenListen(
          cubit,
          const Stream<ProfileState>.empty(),
          initialState: initial,
        );
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('ar'), Locale('en')],
            startLocale: Locale(locale),
            fallbackLocale: const Locale('en'),
            saveLocale: false,
            path: 'assets/lang',
            assetLoader: const LocalTranslationsLoader(),
            child: ScreenUtilInit(
              designSize: const Size(360, 800),
              builder: (context, _) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: BlocProvider<ProfileCubit>.value(
                  value: cubit,
                  child: const MyVouchersScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(locale == 'ar' ? 'ساعة لعب مجاناً' : '1 Free Hour'),
          findsOneWidget,
        );
        expect(
          find.text(locale == 'ar' ? 'خصم 12.5 جنيه' : '12.5 EGP Discount'),
          findsOneWidget,
        );
        expect(
          find.text(locale == 'ar' ? 'التاريخ غير متاح' : 'Date unavailable'),
          findsOneWidget,
        );
        expect(
          ProfileRewardLabels.transaction('booking', 'Completed Booking'),
          locale == 'ar' ? 'حجز مكتمل' : 'Completed booking',
        );
        expect(
          ProfileRewardLabels.level('Gold'),
          locale == 'ar' ? 'ذهبي' : 'Gold',
        );
        expect(
          ProfileRewardLabels.transaction('unknown-custom', 'Customer note'),
          'Customer note',
        );
        if (locale == 'ar') {
          expect(find.textContaining('Valid until'), findsNothing);
          expect(find.textContaining('days remaining'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        final other = locale == 'ar' ? 'en' : 'ar';
        await tester
            .element(find.byType(MyVouchersScreen))
            .setLocale(Locale(other));
        await tester.pumpAndSettle();
        expect(
          find.text(other == 'ar' ? 'ساعة لعب مجاناً' : '1 Free Hour'),
          findsOneWidget,
        );
        expect(
          find.text(other == 'ar' ? 'خصم 12.5 جنيه' : '12.5 EGP Discount'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await cubit.close();
      },
    );
  }
}
