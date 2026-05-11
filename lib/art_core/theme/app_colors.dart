
import 'package:flutter/material.dart';

class AppColors {
  // ─── Primary - Electric Blue #1E88E5 ─────────────────────────
  static const MaterialColor primary = MaterialColor(0xFF1E88E5, <int, Color>{
    0:   Color(0xFFF0F7FF),
    50:  Color(0xFFE3F2FD),
    100: Color(0xFFBBDEFB),
    200: Color(0xFF90CAF9),
    300: Color(0xFF64B5F6),
    400: Color(0xFF42A5F5),
    500: Color(0xFF1E88E5),
    600: Color(0xFF1976D2),
    700: Color(0xFF1565C0),
    800: Color(0xFF0D47A1),
    900: Color(0xFF082F6B),
    950: Color(0xFF041838),
  });

  // ─── Charcoal - #212121 ───────────────────────────────────────
  static const MaterialColor charcoal = MaterialColor(0xFF212121, <int, Color>{
    50:  Color(0xFFF5F5F5),
    100: Color(0xFFE0E0E0),
    200: Color(0xFFBDBDBD),
    300: Color(0xFF9E9E9E),
    400: Color(0xFF757575),
    500: Color(0xFF212121),
    600: Color(0xFF2C2C2C),
    700: Color(0xFF1A1A1A),
    800: Color(0xFF141414),
    900: Color(0xFF0D0D0D),
    950: Color(0xFF080808),
  });

  // ─── Grey ─────────────────────────────────────────────────────
  static const MaterialColor grey = MaterialColor(0xFF9E9E9E, <int, Color>{
    50:  Color(0xFFFAFAFA),
    100: Color(0xFFF5F5F5),
    200: Color(0xFFEEEEEE),
    300: Color(0xFFE0E0E0),
    400: Color(0xFFBDBDBD),
    500: Color(0xFF9E9E9E),
    600: Color(0xFF757575),
    700: Color(0xFF616161),
    800: Color(0xFF424242),
    900: Color(0xFF383838),
    950: Color(0xFF212121),
  });

  // ─── App Background & Surfaces ────────────────────────────────
  static const Color scaffoldBackground = Color(0xFF212121); // main bg
  static const Color cardBackground     = Color(0xFF2C2C2C); // cards
  static const Color sidebarBackground  = Color(0xFF1A1A1A); // sidebar
  static const Color inputField         = Color(0xFF2C2C2C); // input bg
  static const Color divider            = Color(0xFF383838); // borders

  // ─── Text Colors ──────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF); // white
  static const Color textSecondary = Color(0xFF9E9E9E); // muted
  static const Color hintText      = Color(0xFF757575); // placeholder

  // ─── Accent Colors ────────────────────────────────────────────
  static const Color electricBlue = Color(0xFF1E88E5); // primary accent
  static const Color lightBlue    = Color(0xFF42A5F5); // secondary accent
  static const Color darkBlue     = Color(0xFF0D47A1); // deep blue

  // ─── Status Colors ────────────────────────────────────────────
  static const Color success = Color(0xFF66BB6A); // green
  static const Color warning = Color(0xFFFFA726); // amber
  static const Color danger  = Color(0xFFEF5350); // red
  static const Color info    = Color(0xFF1E88E5); // blue

  // ─── Booking Status ───────────────────────────────────────────
  static const Color statusUpcoming  = Color(0xFF1E88E5); // blue
  static const Color statusCompleted = Color(0xFF66BB6A); // green
  static const Color statusCancelled = Color(0xFFEF5350); // red
  static const Color statusPending   = Color(0xFFFFA726); // amber

  // ─── Room Status ──────────────────────────────────────────────
  static const Color roomAvailable   = Color(0xFF66BB6A); // green
  static const Color roomMaintenance = Color(0xFFFFA726); // amber
  static const Color roomBooked      = Color(0xFFEF5350); // red

  // ─── Product Categories ───────────────────────────────────────
  static const Color categoryDrinks = Color(0xFF1E88E5); // blue
  static const Color categoryFood   = Color(0xFFFFA726); // amber
  static const Color categorySnacks = Color(0xFF66BB6A); // green

  // ─── Lounge Status ────────────────────────────────────────────
  static const Color loungeActive   = Color(0xFF66BB6A);
  static const Color loungePending  = Color(0xFFFFA726);
  static const Color loungeDisabled = Color(0xFFEF5350);

  // ─── Misc ─────────────────────────────────────────────────────
  static const Color transparent    = Color(0x00000000);
  static const Color white          = Color(0xFFFFFFFF);
  static const Color black          = Color(0xFF000000);
  static const Color starColor      = Color(0xFFFFA726);
  static const Color disableButton  = Color(0xFF757575);
  static const Color shadowColor    = Color(0x40000000);

  // ─── Shimmer ──────────────────────────────────────────────────
  static const Color shimmerBase      = Color(0xFF2C2C2C);
  static const Color shimmerHighlight = Color(0xFF383838);

  // ─── Helper ───────────────────────────────────────────────────
  static Color withOpacity(Color color, double opacity) =>
      color.withOpacity(opacity);
}

extension ColorExtension on MaterialColor {
  Color get shade0   => this[0]!;
  Color get shade950 => this[950]!;
}