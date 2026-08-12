import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:playspot/art_core/helper/screens_size_handler.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/cubit/locale_cubit.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

import 'art_core/router/AppRouter.dart';
import 'core/di.dart';
import 'features/favorites/presentation/favorites_cubit.dart';
import 'features/profile/presentation/profile_cubit.dart';
import 'features/notifications/presentation/cubit/notifications_cubit.dart';
import 'core/utils/app_bloc_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up BlocObserver to track all actions and state changes
  Bloc.observer = AppBlocObserver();

  // Handle Flutter errors
  FlutterError.onError = (details) {
    dev.log("FLUTTER ERROR: ${details.exception}", stackTrace: details.stack);
  };

  // Handle Platform errors (asynchronous)
  PlatformDispatcher.instance.onError = (error, stack) {
    dev.log("PLATFORM ERROR: $error", stackTrace: stack);
    return true;
  };

  await EasyLocalization.ensureInitialized();
  await init();
  await initSupabase();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appRouter = AppRouter();

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
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: [
            ...context.localizationDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: false,
            scaffoldBackgroundColor: AppColors.scaffoldBackground,
            fontFamily: context.locale.languageCode == 'ar' ? 'Cairo' : 'Orbitron',
          ),
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(),
          ),
          routerConfig: _appRouter.router,
        );
      },
    );
  }
}
