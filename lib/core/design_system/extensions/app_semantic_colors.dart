import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color info;
  final Color success;
  final Color warning;
  final Color textMuted;
  final Color subtext;
  final Color borderSubtle;
  final Color surfaceHigh;
  final Color disabledBackground;

  const AppSemanticColors({
    required this.info,
    required this.success,
    required this.warning,
    required this.textMuted,
    required this.subtext,
    required this.borderSubtle,
    required this.surfaceHigh,
    required this.disabledBackground,
  });

  factory AppSemanticColors.fromPalette(AppPalette palette) {
    return AppSemanticColors(
      info: palette.info,
      success: palette.success,
      warning: palette.warning,
      textMuted: palette.textMuted,
      subtext: palette.subtext,
      borderSubtle: palette.borderSubtle,
      surfaceHigh: palette.surfaceHigh,
      disabledBackground: palette.disabledBackground,
    );
  }

  @override
  AppSemanticColors copyWith({
    Color? info,
    Color? success,
    Color? warning,
    Color? textMuted,
    Color? subtext,
    Color? borderSubtle,
    Color? surfaceHigh,
    Color? disabledBackground,
  }) {
    return AppSemanticColors(
      info: info ?? this.info,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      textMuted: textMuted ?? this.textMuted,
      subtext: subtext ?? this.subtext,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      disabledBackground: disabledBackground ?? this.disabledBackground,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      info: Color.lerp(info, other.info, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      subtext: Color.lerp(subtext, other.subtext, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      disabledBackground: Color.lerp(
        disabledBackground,
        other.disabledBackground,
        t,
      )!,
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
