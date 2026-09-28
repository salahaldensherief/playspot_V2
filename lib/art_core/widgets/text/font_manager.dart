import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class FontsManager {
  static const String englishFontFamily = "Orbitron";

  /// Returns Tajawal Google Font for Arabic
  static String get arabicFontFamily => GoogleFonts.tajawal().fontFamily ?? 'Tajawal';

  /// Helper to check if current locale is Arabic
  static bool isArabic(BuildContext context) {
    try {
      return context.locale.languageCode == 'ar';
    } catch (_) {
      return false;
    }
  }

  /// Returns font family based on current language
  static String getFontFamily(BuildContext context) {
    return isArabic(context) ? arabicFontFamily : englishFontFamily;
  }

  /// Calculates proportioned font size for Arabic vs English
  /// Arabic Tajawal font requires ~12% scale boost to match Orbitron visual height
  static double getScaledFontSize(BuildContext context, double baseSize) {
    if (isArabic(context)) {
      return baseSize * 1.12;
    }
    return baseSize;
  }

  /// Calculates balanced line height for Arabic vs English
  static double getLineHeight(BuildContext context, {double? height}) {
    if (isArabic(context)) {
      // Tajawal has built-in padding; line height between 1.3 and 1.35 is optimal
      return height != null ? (height > 2.0 ? 1.3 : height) : 1.35;
    }
    return height ?? 1.4;
  }

  /// Calculates balanced font weight for Arabic vs English
  static FontWeight getFontWeight(BuildContext context, FontWeight? weight) {
    if (isArabic(context)) {
      final w = weight ?? FontWeight.w400;
      // Upgrade regular (w400) to Medium (w500) for Arabic to match Orbitron's visual presence
      if (w == FontWeight.w400) return FontWeight.w500;
      if (w == FontWeight.w300) return FontWeight.w400;
      return w;
    }
    return weight ?? FontWeight.w400;
  }

  /// Calculates proper letter spacing (Arabic cursive script breaks if letterSpacing > 0)
  static double? getLetterSpacing(BuildContext context, double? spacing) {
    if (isArabic(context)) {
      return 0.0; // Enforce zero letter spacing for cursive Arabic script
    }
    return spacing;
  }

  /// Builds a fully proportioned, language-aware TextStyle for the app
  static TextStyle getStyle({
    required BuildContext context,
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? height,
    String? fontFamily,
    double? letterSpacing,
    TextDecoration? textDecoration,
    List<Shadow>? shadows,
    TextStyle? baseStyle,
  }) {
    final isAr = isArabic(context);
    final rawSize = fontSize ?? 14.sp;
    final finalSize = getScaledFontSize(context, rawSize);
    final finalFamily = fontFamily ?? (isAr ? arabicFontFamily : englishFontFamily);
    final finalWeight = getFontWeight(context, fontWeight ?? baseStyle?.fontWeight);
    final finalHeight = getLineHeight(context, height: height ?? baseStyle?.height);
    final finalLetterSpacing = getLetterSpacing(context, letterSpacing ?? baseStyle?.letterSpacing);

    final defaultColor = color ??
        baseStyle?.color ??
        Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.primary;

    if (baseStyle != null) {
      return baseStyle.copyWith(
        fontSize: finalSize,
        fontFamily: finalFamily,
        fontWeight: finalWeight,
        color: defaultColor,
        height: finalHeight,
        letterSpacing: finalLetterSpacing,
        decoration: textDecoration ?? baseStyle.decoration,
        shadows: shadows ?? baseStyle.shadows,
      );
    }

    return TextStyle(
      fontSize: finalSize,
      color: defaultColor,
      fontWeight: finalWeight,
      height: finalHeight,
      fontFamily: finalFamily,
      letterSpacing: finalLetterSpacing,
      decoration: textDecoration,
      decorationColor: defaultColor,
      shadows: shadows,
    );
  }
}
