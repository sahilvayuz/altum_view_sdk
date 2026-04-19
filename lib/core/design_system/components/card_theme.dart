import 'package:flutter/material.dart';

import '../app_radius.dart';
import '../app_spacing.dart';
import '../tokens/app_palette.dart';

abstract final class AppCardTheme {
  static CardThemeData build(AppPalette palette) {
    return CardThemeData(
      elevation: 1,
      shadowColor: palette.border.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      color: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusMd,
      ),
      margin: const EdgeInsets.all(AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
    );
  }
}
