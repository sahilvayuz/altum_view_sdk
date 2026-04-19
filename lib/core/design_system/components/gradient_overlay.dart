import 'package:flutter/material.dart';

class ALGradientOverlay extends StatelessWidget {
  const ALGradientOverlay({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.white70, Colors.white],
          ),
        ),
      ),
    );
  }
}
