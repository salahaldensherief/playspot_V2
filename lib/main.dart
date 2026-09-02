import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:playspot/art_core/helper/screens_size_handler.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:playspot/firebase_options.dart';
import 'art_core/router/app_router.dart';
import 'core/di.dart';
import 'core/notifications/firebase_background_handler.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/utils/app_bloc_observer.dart';
import 'package:playspot/art_core/widgets/notifications/game_hud_toast.dart';
import 'features/profile/domain/repositories/profile_repository.dart';

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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await EasyLocalization.ensureInitialized();
  await init();
  await initSupabase();

  // Register Firebase background handler
  FirebaseMessaging.onBackgroundMessage(handleFirebaseBackgroundMessage);

  // Initialize Notifications
  await LocalNotificationService.instance.initialize();
  await PushNotificationService.instance.initialize(
    localNotifications: LocalNotificationService.instance,
    profileRepository: sl<ProfileRepository>(),
  );

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

  // Handle pending initial notification if any
  LocalNotificationService.instance.handlePendingInitialNotification();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appRouter = AppRouter();

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    PushNotificationService.instance.notificationEvents.listen((content) {
      if (content.hasVisibleContent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = AppRouter.navigatorKey.currentContext;
          if (context != null) {
            GameHudToast.show(
              context,
              content.body ?? content.title ?? "",
              type: ToastType.info,
            );
          }
        });
      }
    });
  }

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
