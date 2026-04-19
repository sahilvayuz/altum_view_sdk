import 'package:flutter/material.dart';

import 'tokens/app_palette.dart';

@immutable
class AppThemeConfig {
  final AppPalette lightPalette;
  final AppPalette darkPalette;
  final String fontFamily;

  const AppThemeConfig({
    this.lightPalette = AppPalettes.light,
    this.darkPalette = AppPalettes.dark,
    this.fontFamily = 'Mukta',
  });

  AppThemeConfig copyWith({
    AppPalette? lightPalette,
    AppPalette? darkPalette,
    String? fontFamily,
  }) {
    return AppThemeConfig(
      lightPalette: lightPalette ?? this.lightPalette,
      darkPalette: darkPalette ?? this.darkPalette,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}
