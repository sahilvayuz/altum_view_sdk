import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextTheme textTheme(String fontFamily) => TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 57,
      fontWeight: FontWeight.w400,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 45,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 36,
      fontWeight: FontWeight.w400,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 32,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w500,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
  );
}
