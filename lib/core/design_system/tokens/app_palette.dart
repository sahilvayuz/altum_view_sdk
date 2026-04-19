import 'package:flutter/material.dart';

@immutable
class AppPalette {
  final Color brandPrimary;
  final Color brandSecondary;
  final Color brandAccent;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color subtext;
  final Color border;
  final Color borderSubtle;
  final Color inputBorder;
  final Color info;
  final Color success;
  final Color warning;
  final Color error;
  final Color onPrimary;
  final Color onSecondary;
  final Color onAccent;
  final Color onError;
  final Color disabledBackground;

  const AppPalette({
    required this.brandPrimary,
    required this.brandSecondary,
    required this.brandAccent,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.subtext,
    required this.border,
    required this.borderSubtle,
    required this.inputBorder,
    required this.info,
    required this.success,
    required this.warning,
    required this.error,
    required this.onPrimary,
    required this.onSecondary,
    required this.onAccent,
    required this.onError,
    required this.disabledBackground,
  });
}

abstract final class AppPalettes {
  static const light = AppPalette(
    brandPrimary: Color(0xFF092C4C),
    brandSecondary: Color(0xFFF2994A),
    brandAccent: Color(0xFFA3CEF1),
    background: Color(0xFFFBF8F3),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1D1D1D),
    textSecondary: Color(0xFF4F4F4F),
    textMuted: Color(0xFF828282),
    subtext: Color(0xFF333333),
    border: Color(0xFFBDBDBD),
    borderSubtle: Color(0xFFE0E0E0),
    inputBorder: Color(0x243E4968),
    info: Color(0xFF2F80ED),
    success: Color(0xFF27AE60),
    warning: Color(0xFFE2B93B),
    error: Color(0xFFEB5757),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onAccent: Color(0xFF092C4C),
    onError: Color(0xFFFFFFFF),
    disabledBackground: Color(0xFF828282),
  );

  static const dark = AppPalette(
    brandPrimary: Color(0xFFD0BCFF),
    brandSecondary: Color(0xFFCCC2DC),
    brandAccent: Color(0xFFEFB8C8),
    background: Color(0xFF1C1B1F),
    surface: Color(0xFF2B2930),
    surfaceHigh: Color(0xFF49454F),
    textPrimary: Color(0xFFE6E1E5),
    textSecondary: Color(0xFFCAC4D0),
    textMuted: Color(0xFF938F99),
    subtext: Color(0xFF333333),
    border: Color(0xFF938F99),
    borderSubtle: Color(0xFF49454F),
    inputBorder: Color(0x243E4968),
    info: Color(0xFF4FC3F7),
    success: Color(0xFF81C784),
    warning: Color(0xFFFFD54F),
    error: Color(0xFFF2B8B5),
    onPrimary: Color(0xFF381E72),
    onSecondary: Color(0xFF332D41),
    onAccent: Color(0xFF492532),
    onError: Color(0xFF601410),
    disabledBackground: Color(0xFF49454F),
  );
}
