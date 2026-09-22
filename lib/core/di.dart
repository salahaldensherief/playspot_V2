import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/app_config.dart';
import 'di/modules/core_module.dart';
import 'di/modules/auth_module.dart';
import 'di/modules/home_module.dart';
import 'di/modules/booking_module.dart';
import 'di/modules/lounge_module.dart';
import 'di/modules/my_bookings_module.dart';
import 'di/modules/profile_module.dart';
import 'di/modules/favorites_module.dart';
import 'di/modules/notifications_module.dart';
import 'di/modules/active_session_module.dart';
import 'di/modules/tournaments_module.dart';
import 'di/modules/app_status_module.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Core services & Cache
  await initCoreModule();
  
  // Feature modules
  initAuthModule();
  initHomeModule();
  initLoungeModule();
  initBookingModule();
  initMyBookingsModule();
  initProfileModule();
  initFavoritesModule();
  initNotificationsModule();
  initActiveSessionModule();
  initTournamentsModule();
  initAppStatusModule();
}


Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
}

