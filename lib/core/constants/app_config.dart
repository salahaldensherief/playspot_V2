import 'dart:io';

import 'package:flutter/material.dart';

import '../cache/preference_manager.dart';

class AppConfig {
  // App Information
  static const String appName = "PlaySpot";
  static const String appVersion = "1.1.1";

  // Context-aware isDarkMode for widgets usage
  static bool isDarkModeWithContext(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  ///********************* Localization *********************///
  static const String _englishLanguageCode = "en";
  static const String _arabicLanguageCode = "ar";
  static const List<Locale> supportedLanguages = [
    Locale(_englishLanguageCode),
    Locale(_arabicLanguageCode),
  ];

  static bool get isEnglish =>
      PreferenceManager().currentLang() == _englishLanguageCode;

  static bool get isArabic =>
      PreferenceManager().currentLang() == _arabicLanguageCode;

  // Currency
  static const String defaultCurrency = "EGP";

  // Timeout Durations
  static const Duration apiTimeout = Duration(seconds: 30);

  ///********************* App Settings *********************///
  static void hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static String kGoogleApiKey = Platform.isIOS
      ? const String.fromEnvironment(
          'GOOGLE_API_KEY_IOS',
          defaultValue: 'AIzaSyC67gDDTt0enFRQdH7ca1ex5FYIezlKqg4',
        )
      : const String.fromEnvironment(
          'GOOGLE_API_KEY_ANDROID',
          defaultValue: 'AIzaSyDmBCl0ScTRCDyoLdkphhr0JLYjDgGBry4',
        );

  /// Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tgpdexoitemmpruepgyt.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRncGRleG9pdGVtbXBydWVwZ3l0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2NjYyNzYsImV4cCI6MjA5NDI0MjI3Nn0.i5ekdw4CkWh97-BGWzCRQZ4c9bIKWIo2vD-Ev58BVC4',
  );
}

