import 'package:flutter/material.dart';

import '../app_radius.dart';
import '../tokens/app_palette.dart';

abstract final class AppAppBarTheme {
  static AppBarTheme build(AppPalette palette, TextTheme textTheme) {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      backgroundColor: palette.background,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: palette.brandPrimary,
      shadowColor: palette.border.withValues(alpha: 0.1),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: palette.textPrimary,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary, size: 24),
      actionsIconTheme: IconThemeData(color: palette.textPrimary, size: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: AppRadius.radiusMd,
          bottomRight: AppRadius.radiusMd,
        ),
      ),
    );
  }
}
