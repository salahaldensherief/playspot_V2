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
      ? "AIzaSyC67gDDTt0enFRQdH7ca1ex5FYIezlKqg4"
      : "AIzaSyDmBCl0ScTRCDyoLdkphhr0JLYjDgGBry4";
}
