import 'package:flutter/material.dart';

import 'app_theme_config.dart';
import 'app_typography.dart';
import 'components/app_bar_theme.dart';
import 'components/button_theme.dart';
import 'components/card_theme.dart';
import 'components/input_theme.dart';
import 'extensions/app_semantic_colors.dart';
import 'tokens/app_palette.dart';

abstract final class AppTheme {
  static const _defaultConfig = AppThemeConfig();

  static ThemeData lightTheme([AppThemeConfig? config]) {
    final cfg = config ?? _defaultConfig;
    return _buildTheme(cfg.lightPalette, Brightness.light, cfg.fontFamily);
  }

  static ThemeData darkTheme([AppThemeConfig? config]) {
    final cfg = config ?? _defaultConfig;
    return _buildTheme(cfg.darkPalette, Brightness.dark, cfg.fontFamily);
  }

  static ColorScheme _buildColorScheme(
    AppPalette palette,
    Brightness brightness,
  ) {
    return ColorScheme(
      brightness: brightness,
      primary: palette.brandPrimary,
      onPrimary: palette.onPrimary,
      primaryContainer: palette.brandPrimary.withValues(alpha: 0.12),
      onPrimaryContainer: palette.brandPrimary,
      secondary: palette.brandSecondary,
      onSecondary: palette.onSecondary,
      secondaryContainer: palette.brandSecondary.withValues(alpha: 0.12),
      onSecondaryContainer: palette.brandSecondary,
      tertiary: palette.brandAccent,
      onTertiary: palette.onAccent,
      tertiaryContainer: palette.brandAccent.withValues(alpha: 0.12),
      onTertiaryContainer: palette.brandAccent,
      error: palette.error,
      onError: palette.onError,
      errorContainer: palette.error.withValues(alpha: 0.12),
      onErrorContainer: palette.error,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.surfaceHigh,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.border,
      outlineVariant: palette.borderSubtle,
      shadow: palette.textPrimary.withValues(alpha: 0.15),
      scrim: palette.textPrimary.withValues(alpha: 0.32),
      inverseSurface: palette.textPrimary,
      onInverseSurface: palette.surface,
      inversePrimary: brightness == Brightness.light
          ? AppPalettes.dark.brandPrimary
          : AppPalettes.light.brandPrimary,
    );
  }

  static ThemeData _buildTheme(
    AppPalette palette,
    Brightness brightness,
    String fontFamily,
  ) {
    final colorScheme = _buildColorScheme(palette, brightness);
    final textTheme = AppTypography.textTheme(fontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: palette.surface,
      appBarTheme: AppAppBarTheme.build(palette, textTheme),
      elevatedButtonTheme: AppButtonTheme.elevatedButtonTheme(
        palette,
        textTheme,
      ),
      outlinedButtonTheme: AppButtonTheme.outlinedButtonTheme(
        palette,
        textTheme,
      ),
      textButtonTheme: AppButtonTheme.textButtonTheme(palette, textTheme),
      filledButtonTheme: AppButtonTheme.filledButtonTheme(palette, textTheme),
      cardTheme: AppCardTheme.build(palette),
      inputDecorationTheme: AppInputTheme.build(palette, textTheme),
      dividerTheme: DividerThemeData(
        color: palette.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary, size: 24),
      extensions: [AppSemanticColors.fromPalette(palette)],
    );
  }
}
