import 'package:flutter/material.dart';

class AppColors {
  // ─── Primary - Neon Blue #00D9FF ─────────────────────────────
  static const MaterialColor primary = MaterialColor(0xFF00D9FF, <int, Color>{
    0:   Color(0xFFE0FAFF),
    50:  Color(0xFFB3F4FF),
    100: Color(0xFF80EEFF),
    200: Color(0xFF4DE8FF),
    300: Color(0xFF1AE2FF),
    400: Color(0xFF00D9FF),
    500: Color(0xFF00D4FF),
    600: Color(0xFF00B8D9),
    700: Color(0xFF0099B3),
    800: Color(0xFF006B7D),
    900: Color(0xFF003D47),
    950: Color(0xFF001E24),
  });

  // ─── Secondary - Neon Purple #A855F7 ─────────────────────────
  static const MaterialColor purple = MaterialColor(0xFFA855F7, <int, Color>{
    0:   Color(0xFFF5E6FF),
    50:  Color(0xFFEDD5FE),
    100: Color(0xFFD9AAFD),
    200: Color(0xFFC57FFB),
    300: Color(0xFFB154F9),
    400: Color(0xFFA855F7),
    500: Color(0xFF8B5CF6),
    600: Color(0xFF7C3AED),
    700: Color(0xFF6D28D9),
    800: Color(0xFF5B21B6),
    900: Color(0xFF4C1D95),
    950: Color(0xFF2E1065),
  });

  // ─── Backgrounds ──────────────────────────────────────────────
  static const Color scaffoldBackground = Color(0xFF0A0A0F);
  static const Color backgroundAlt      = Color(0xFF0D0D0D);
  static const Color cardBackground     = Color(0xFF1A1A24);
  static const Color mutedBackground    = Color(0xFF1F1F2E);
  static const Color inputField         = Color(0xFF1A1A24);

  // ─── Text ─────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color hintText      = Color(0xFF9CA3AF);
  static const Color splashHint    = Color(0xFF9CA3AF); // alias for hintText

  // ─── Accent / Neon ────────────────────────────────────────────
  static const Color neonBlue      = Color(0xFF00D9FF);
  static const Color neonBlueAlt   = Color(0xFF00D4FF);
  static const Color neonPurple    = Color(0xFFA855F7);
  static const Color purpleVariant = Color(0xFF8B5CF6);
  static const Color cyan          = Color(0xFF06B6D4);
  static const Color lightPurple   = Color(0xFFC084FC);

  // lightBlue alias — used across onboarding & splash
  static const Color lightBlue     = Color(0xFF00D9FF);

  // ─── Gradient ─────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: const [0.8, 1.0],
    colors: [Color(0xFF00D9FF), Color(0xFFA855F7)],
  );

  // ─── Buttons ──────────────────────────────────────────────────
  static const Color buttonPrimary     = Color(0xFF00D9FF);
  static const Color buttonPrimary2    = Color(0xFF1B1A24);
  static const Color buttonPrimaryText = Color(0xFF0A0A0F);
  static const Color buttonDeactive    = Color(0xFF1F1F2E); // deactivated button bg
  static const Color disableButton     = Color(0xFF9CA3AF);

  // ─── Status — Success ─────────────────────────────────────────
  static const Color success           = Color(0xFF22C55E);
  static const Color successBackground = Color(0x3322C55E);
  static const Color successBorder     = Color(0x6622C55E);

  // ─── Status — Error ───────────────────────────────────────────
  static const Color danger            = Color(0xFFEF4444);
  static const Color dangerDark        = Color(0xFFD4183D);
  static const Color dangerBackground  = Color(0x33EF4444);
  static const Color dangerBorder      = Color(0x66EF4444);

  // ─── Status — Warning ─────────────────────────────────────────
  static const Color warning   = Color(0xFFFBBF24);
  static const Color starColor = Color(0xFFFBBF24);

  // ─── Booking Status ───────────────────────────────────────────
  static const Color statusUpcoming  = Color(0xFF00D9FF);
  static const Color statusCompleted = Color(0xFF22C55E);
  static const Color statusCancelled = Color(0xFFEF4444);
  static const Color statusPending   = Color(0xFFFBBF24);

  // ─── Room Status ──────────────────────────────────────────────
  static const Color roomAvailable   = Color(0xFF22C55E);
  static const Color roomBooked      = Color(0xFFEF4444);
  static const Color roomMaintenance = Color(0xFFFBBF24);

  // ─── Product Categories ───────────────────────────────────────
  static const Color categoryDrinks = Color(0xFF00D9FF);
  static const Color categoryFood   = Color(0xFFFBBF24);
  static const Color categorySnacks = Color(0xFFA855F7);

  // ─── Borders & Dividers ───────────────────────────────────────
  static const Color borderDefault = Color(0x1AFFFFFF);
  static const Color borderSubtle  = Color(0x0DFFFFFF);
  static const Color divider       = Color(0x1AFFFFFF);

  // ─── Glass & Overlays ─────────────────────────────────────────
  static final Color glassBackground = Colors.white.withOpacity(0.03);
  static final Color glassBorder = Colors.white.withOpacity(0.08);
  static final Color blackOverlay = Colors.black.withOpacity(0.6);
  static final Color whiteOverlay = Colors.white.withOpacity(0.05);

  // ─── Neon Blue Overlays ───────────────────────────────────────
  static const Color neonBlue10 = Color(0x1A00D4FF);
  static const Color neonBlue20 = Color(0x3300D4FF);
  static const Color neonBlue30 = Color(0x4D00D4FF);
  static const Color neonBlue40 = Color(0x6600D4FF);
  static const Color neonBlue50 = Color(0x8000D4FF);

  // ─── Neon Purple Overlays ─────────────────────────────────────
  static const Color neonPurple10 = Color(0x1AA855F7);
  static const Color neonPurple20 = Color(0x33A855F7);
  static const Color neonPurple30 = Color(0x4DA855F7);

  // ─── Misc ─────────────────────────────────────────────────────
  static const Color transparent = Color(0x00000000);
  static const Color white       = Color(0xFFFFFFFF);
  static const Color black       = Color(0xFF000000);
  static const Color shadowColor = Color(0x8000D4FF);

  // ─── Shimmer ──────────────────────────────────────────────────
  static const Color shimmerBase      = Color(0xFF1A1A24);
  static const Color shimmerHighlight = Color(0xFF1F1F2E);

  // ─── Helper ───────────────────────────────────────────────────
  static Color withOpacity(Color color, double opacity) =>
      color.withOpacity(opacity);
}

extension ColorExtension on MaterialColor {
  Color get shade0   => this[0]!;
  Color get shade950 => this[950]!;
}