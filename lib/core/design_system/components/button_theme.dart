import 'package:flutter/material.dart';

import '../app_radius.dart';
import '../app_spacing.dart';
import '../tokens/app_palette.dart';

abstract final class AppButtonTheme {
  static ElevatedButtonThemeData elevatedButtonTheme(
    AppPalette palette,
    TextTheme textTheme,
  ) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.brandPrimary,
        foregroundColor: palette.onPrimary,
        disabledBackgroundColor: palette.border.withValues(alpha: 0.12),
        disabledForegroundColor: palette.textPrimary.withValues(alpha: 0.38),
        elevation: 1,
        shadowColor: palette.brandPrimary.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusMd,
        ),
        textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.1),
      ),
    );
  }

  static OutlinedButtonThemeData outlinedButtonTheme(
    AppPalette palette,
    TextTheme textTheme,
  ) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.brandPrimary,
        disabledForegroundColor: palette.textPrimary.withValues(alpha: 0.38),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusMd,
        ),
        side: BorderSide(color: palette.border),
        textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.1),
      ),
    );
  }

  static TextButtonThemeData textButtonTheme(
    AppPalette palette,
    TextTheme textTheme,
  ) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.brandPrimary,
        disabledForegroundColor: palette.textPrimary.withValues(alpha: 0.38),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusMd,
        ),
        textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.1),
      ),
    );
  }

  static FilledButtonThemeData filledButtonTheme(
    AppPalette palette,
    TextTheme textTheme,
  ) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.brandPrimary,
        foregroundColor: palette.onPrimary,
        disabledBackgroundColor: palette.border.withValues(alpha: 0.12),
        disabledForegroundColor: palette.textPrimary.withValues(alpha: 0.38),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusMd,
        ),
        textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.1),
      ),
    );
  }
}
