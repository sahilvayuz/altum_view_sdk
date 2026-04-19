import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const sm = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 3,
      offset: Offset(0, 1),
      spreadRadius: 1,
    ),
  ];

  static const md = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 2)),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 6,
      offset: Offset(0, 4),
      spreadRadius: 2,
    ),
  ];

  static const lg = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 4),
      spreadRadius: 2,
    ),
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 16,
      offset: Offset(0, 8),
      spreadRadius: 4,
    ),
  ];

  static const pill = [BoxShadow(color: Color(0x40000000), blurRadius: 10)];

  static const xl = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 10,
      offset: Offset(0, 6),
      spreadRadius: 3,
    ),
    BoxShadow(
      color: Color(0x29000000),
      blurRadius: 24,
      offset: Offset(0, 12),
      spreadRadius: 6,
    ),
  ];
}
