import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../cache/preference_manager.dart';

class AppConfig {
  // App Information
  static const String appName = "PlaySpot";

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

  /// Injected at build time via --dart-define.
  static String kGoogleApiKey = !kIsWeb && Platform.isIOS
      ? const String.fromEnvironment('GOOGLE_API_KEY_IOS')
      : const String.fromEnvironment('GOOGLE_API_KEY_ANDROID');

  /// Supabase configuration is required at build time via --dart-define.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
}
