import 'package:flutter/material.dart';

class CallTimerDisplay extends StatelessWidget {
  final Duration duration;

  const CallTimerDisplay({super.key, required this.duration});

  String get _formatted {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w200,
        letterSpacing: 4,
        color: Colors.white,
        fontFeatures: [const FontFeature.tabularFigures()],
      ),
    );
  }
}