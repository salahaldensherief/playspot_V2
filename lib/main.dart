import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/helper/screens_size_handler.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

import 'art_core/router/AppRouter.dart';
import 'core/di.dart';
import 'core/di/modules/auth_module.dart';
import 'features/favorites/presentation/favorites_cubit.dart';
import 'features/profile/presentation/profile_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await init();
  await initSupabase();


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
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => sl<FavoritesCubit>()..getFavoriteIds(),
            ),
            BlocProvider(
              create: (context) => sl<ProfileCubit>()..getUserData(),
            ),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'PlaySpot',
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: ThemeData(
              useMaterial3: false,
              scaffoldBackgroundColor: AppColors.scaffoldBackground,
              fontFamily: 'Orbitron',
            ),
            routerConfig: _appRouter.router,
          ),
        );
      },
    );
  }
}