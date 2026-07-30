import 'package:supabase_flutter/supabase_flutter.dart';
import 'di/modules/core_module.dart';
import 'di/modules/auth_module.dart';
import 'di/modules/home_module.dart';
import 'di/modules/booking_module.dart';
import 'di/modules/lounge_module.dart';
import 'di/modules/my_bookings_module.dart';
import 'di/modules/profile_module.dart';
import 'di/modules/favorites_module.dart';

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
}

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: 'https://tgpdexoitemmpruepgyt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRncGRleG9pdGVtbXBydWVwZ3l0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2NjYyNzYsImV4cCI6MjA5NDI0MjI3Nn0.i5ekdw4CkWh97-BGWzCRQZ4c9bIKWIo2vD-Ev58BVC4',
  );
}
