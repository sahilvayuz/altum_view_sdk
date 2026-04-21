// ─────────────────────────────────────────────────────────────────────────────
// core/theme/app_theme.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class AppTheme {
  // ── Colors ─────────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF0A84FF);
  static const Color primaryDark   = Color(0xFF0066CC);
  static const Color surface       = Color(0xFF1C1C1E);
  static const Color surfaceCard   = Color(0xFF2C2C2E);
  static const Color surfaceCard2  = Color(0xFF3A3A3C);
  static const Color background    = Color(0xFF000000);
  static const Color onBackground  = Color(0xFFFFFFFF);
  static const Color onSurface     = Color(0xFFEBEBF5);
  static const Color onSurfaceSub  = Color(0xFF8E8E93);
  static const Color success       = Color(0xFF30D158);
  static const Color warning       = Color(0xFFFF9F0A);
  static const Color error         = Color(0xFFFF453A);
  static const Color divider       = Color(0xFF38383A);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      surface: surface,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: onBackground,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: primary),
    ),
    cardTheme: CardThemeData(
      color: surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: TextStyle(color: onSurfaceSub),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(color: divider, thickness: 0.5),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor: Colors.transparent,
    ),
  );
}