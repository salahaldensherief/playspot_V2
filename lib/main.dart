import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/helper/screens_size_handler.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

import 'art_core/router/AppRouter.dart';
import 'core/di.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await init();


  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
      ],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: DeviceTypeHelper.getSize(context),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'PlaySpot',

          // easy_localization
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,

          theme: ThemeData(
            scaffoldBackgroundColor: AppColors.scaffoldBackground,
            fontFamily: 'Orbitron',
          ),
          routerConfig: AppRouter().router,
        );
      },
    );
  }
}