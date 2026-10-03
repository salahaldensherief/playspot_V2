import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:playspot/art_core/helper/screens_size_handler.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:playspot/firebase_options.dart';
import 'art_core/router/app_router.dart';
import 'core/di.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/network_connectivity_service.dart';
import 'art_core/widgets/notifications/network_status_banner.dart';
import 'core/notifications/firebase_background_handler.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/utils/app_bloc_observer.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import 'core/services/play_spot_live_activity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.scaffoldBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  Bloc.observer = AppBlocObserver();

  FlutterError.onError = (details) {
    // Keep framework failures visible in the attached console and adb logcat.
    // dev.log alone only reaches the VM logging stream.
    if (kDebugMode) FlutterError.presentError(details);
    dev.log("FLUTTER ERROR: ${details.exception}", stackTrace: details.stack);
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('[APP-ERROR] unhandled ${error.runtimeType}');
      debugPrintStack(stackTrace: stack);
    }
    dev.log("PLATFORM ERROR: $error", stackTrace: stack);
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    EasyLocalization.ensureInitialized(),
    init(),
    initSupabase(),
  ]);

  // Explicitly enable Crashlytics collection for production error tracking
  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  }

  NetworkConnectivityService().initialize();

  sl<DeepLinkService>().initialize();

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(handleFirebaseBackgroundMessage);
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );

  _initPostAppServices();
}

void _initPostAppServices() {
  try {
    LocalNotificationService.instance
        .initialize()
        .then((_) {
          PushNotificationService.instance.initialize(
            localNotifications: LocalNotificationService.instance,
            profileRepository: sl<ProfileRepository>(),
          );
          LocalNotificationService.instance.handlePendingInitialNotification();
        })
        .catchError((e) {
          dev.log("NOTIFICATION INIT ERROR: $e");
        });
  } catch (e) {
    dev.log("POST APP NOTIFICATION INIT EXCEPTION: $e");
  }

  try {
    PlaySpotLiveActivityService.instance.init().catchError((e) {
      dev.log("LIVE ACTIVITY INIT ERROR: $e");
    });
  } catch (e) {
    dev.log("LIVE ACTIVITY INIT EXCEPTION: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

final _appRouter = AppRouter();

final _arTheme = ThemeData(
  useMaterial3: false,
  scaffoldBackgroundColor: AppColors.scaffoldBackground,
  fontFamily: 'Tajawal',
  textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Tajawal'),
);

final _enTheme = ThemeData(
  useMaterial3: false,
  scaffoldBackgroundColor: AppColors.scaffoldBackground,
  fontFamily: 'Orbitron',
  textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Orbitron'),
);

class _MyAppState extends State<MyApp> {
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
          theme: context.locale.languageCode == 'ar' ? _arTheme : _enTheme,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(),
          ),
          routerConfig: _appRouter.router,
          builder: (context, child) {
            return NetworkStatusWrapper(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
