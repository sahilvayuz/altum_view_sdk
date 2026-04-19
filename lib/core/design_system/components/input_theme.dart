import 'package:flutter/material.dart';

import '../app_radius.dart';
import '../tokens/app_palette.dart';

abstract final class AppInputTheme {
  static InputDecorationTheme build(AppPalette palette, TextTheme textTheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSm,
        borderSide: BorderSide(color: palette.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSm,
        borderSide: BorderSide(color: palette.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSm,
        borderSide: BorderSide(color: palette.brandPrimary, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSm,
        borderSide: BorderSide(color: palette.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSm,
        borderSide: BorderSide(color: palette.error, width: 1),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSm,
        borderSide: BorderSide(
          color: palette.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      hintStyle: textTheme.bodySmall?.copyWith(color: palette.textMuted),
      errorStyle: textTheme.bodySmall?.copyWith(color: palette.error),
      prefixIconColor: palette.textSecondary,
      suffixIconColor: palette.textSecondary,
    );
  }
}
