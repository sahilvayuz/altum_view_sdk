import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 9999;

  static const borderRadiusXs = BorderRadius.all(Radius.circular(xs));
  static const borderRadiusSm = BorderRadius.all(Radius.circular(sm));
  static const borderRadiusMd = BorderRadius.all(Radius.circular(md));
  static const borderRadiusLg = BorderRadius.all(Radius.circular(lg));
  static const borderRadiusXl = BorderRadius.all(Radius.circular(xl));
  static const borderRadiusFull = BorderRadius.all(Radius.circular(full));

  static const radiusXs = Radius.circular(xs);
  static const radiusSm = Radius.circular(sm);
  static const radiusMd = Radius.circular(md);
  static const radiusLg = Radius.circular(lg);
  static const radiusXl = Radius.circular(xl);
}
