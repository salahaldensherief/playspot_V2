import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class FontsManager {
  static String getFontFamily(BuildContext context) {
    return context.locale.languageCode == 'ar' ? arabicFontFamily : englishFontFamily;
  }

  // Fonts
  static const String arabicFontFamily = "Cairo";
  static const String englishFontFamily = "Orbitron";
}
