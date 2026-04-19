import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const paddingXs = EdgeInsets.all(xs);
  static const paddingSm = EdgeInsets.all(sm);
  static const paddingMd = EdgeInsets.all(md);
  static const paddingLg = EdgeInsets.all(lg);
  static const paddingXl = EdgeInsets.all(xl);
  static const paddingXxl = EdgeInsets.all(xxl);

  static const horizontalPaddingXs = EdgeInsets.symmetric(horizontal: xs);
  static const horizontalPaddingSm = EdgeInsets.symmetric(horizontal: sm);
  static const horizontalPaddingMd = EdgeInsets.symmetric(horizontal: md);
  static const horizontalPaddingLg = EdgeInsets.symmetric(horizontal: lg);
  static const horizontalPaddingXl = EdgeInsets.symmetric(horizontal: xl);

  static const verticalPaddingXs = EdgeInsets.symmetric(vertical: xs);
  static const verticalPaddingSm = EdgeInsets.symmetric(vertical: sm);
  static const verticalPaddingMd = EdgeInsets.symmetric(vertical: md);
  static const verticalPaddingLg = EdgeInsets.symmetric(vertical: lg);
  static const verticalPaddingXl = EdgeInsets.symmetric(vertical: xl);

  static const horizontalGapXs = SizedBox(width: xs);
  static const horizontalGapSm = SizedBox(width: sm);
  static const horizontalGapMd = SizedBox(width: md);
  static const horizontalGapLg = SizedBox(width: lg);
  static const horizontalGapXl = SizedBox(width: xl);

  static const verticalGapXs = SizedBox(height: xs);
  static const verticalGapSm = SizedBox(height: sm);
  static const verticalGapMd = SizedBox(height: md);
  static const verticalGapLg = SizedBox(height: lg);
  static const verticalGapXl = SizedBox(height: xl);
  static const verticalGapXXl = SizedBox(height: xxl);
}
