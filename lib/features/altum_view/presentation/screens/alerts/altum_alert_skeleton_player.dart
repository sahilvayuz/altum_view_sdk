// ─────────────────────────────────────────────────────────────────────────────
// altum_alert_skeleton_player.dart
//
// Plays back a parsed alert skeleton animation frame by frame.
// Uses the same bone definitions and painter style as the live stream.
//
// Usage:
//   AltumAlertSkeletonPlayer(
//     skeletonBytes: base64Decode(detail.skeletonFileB64!),
//   )
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';
import 'package:altum_view_sdk/features/altum_view/helpers/altum_skeleton_parser_helper.dart';
import 'package:flutter/material.dart';

// Same bone connections as live stream
const List<List<int>> _kBones = [
  [0, 1], [1, 2], [1, 5],
  [2, 3], [3, 4], [5, 6], [6, 7],
  [1, 8], [1, 11], [8, 9], [9, 10],
  [11, 12], [12, 13],
  [0, 14], [0, 15], [14, 16], [15, 17],
];

Color _segColor(int bi) {
  if (bi == 0 || bi >= 13) return const Color(0xFF00FFCC);
  if (bi <= 6) return const Color(0xFF4A9EFF);
  if (bi <= 8) return const Color(0xFFFFD700);
  return const Color(0xFFFF6B9D);
}

class AltumAlertSkeletonPlayer extends StatefulWidget {
  final Uint8List skeletonBytes;

  const AltumAlertSkeletonPlayer({super.key, required this.skeletonBytes});

  @override
  State<AltumAlertSkeletonPlayer> createState() => _PlayerState();
}

class _PlayerState extends State<AltumAlertSkeletonPlayer> {
  ParsedAlertSkeleton? _skeleton;
  int     _frameIdx  = 0;
  bool    _playing   = false;
  bool    _parsed    = false;

  @override
  void initState() {
    super.initState();
    _parseSkeleton();
  }

  void _parseSkeleton() {
    // Convert raw bytes to base64 then parse
    final b64 = base64Encode(widget.skeletonBytes);
    final parsed = AltumAlertSkeletonParser.parse(b64);
    if (mounted) setState(() { _skeleton = parsed; _parsed = true; });
  }

  void _play() {
    if (_skeleton == null || _playing) return;
    setState(() { _playing = true; _frameIdx = 0; });
    _tick();
  }

  void _tick() async {
    final sk = _skeleton!;
    while (_playing && _frameIdx < sk.frames.length - 1) {
      final current = sk.frames[_frameIdx];
      final next    = sk.frames[_frameIdx + 1];
      // Wait the real time between frames
      final delay = (next.msDelta - current.msDelta).clamp(33, 500);
      await Future.delayed(Duration(milliseconds: delay));
      if (!mounted || !_playing) break;
      setState(() => _frameIdx++);
    }
    if (mounted) setState(() => _playing = false);
  }

  void _pause()  => setState(() => _playing = false);
  void _rewind() => setState(() { _playing = false; _frameIdx = 0; });

  @override
  void dispose() {
    _playing = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_parsed) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF00DC78))),
      );
    }

    if (_skeleton == null || _skeleton!.frames.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF08141F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF0F2030)),
        ),
        child: const Center(
          child: Text('Skeleton data unavailable',
              style: TextStyle(color: Color(0xFF2A4A6A))),
        ),
      );
    }

    final sk    = _skeleton!;
    final frame = sk.frames[_frameIdx];
    final total = sk.frames.length;

    return Column(children: [
      // Canvas
      AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF050D1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00DC78).withOpacity(0.25), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: CustomPaint(
              painter: _AlertSkeletonPainter(frame: frame),
            ),
          ),
        ),
      ),

      const SizedBox(height: 10),

      // Scrubber
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor:   const Color(0xFF00DC78),
          inactiveTrackColor: const Color(0xFF0F2030),
          thumbColor:         const Color(0xFF00DC78),
          overlayColor:       const Color(0xFF00DC78).withOpacity(0.2),
          thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 6),
          trackHeight:        2,
        ),
        child: Slider(
          value:  _frameIdx.toDouble(),
          min:    0,
          max:    (total - 1).toDouble(),
          onChanged: (v) => setState(() { _frameIdx = v.toInt(); _playing = false; }),
        ),
      ),

      // Controls + info
      Row(children: [
        // Rewind
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, color: Color(0xFF4A7FA8)),
          onPressed: _rewind,
        ),
        // Play/Pause
        IconButton(
          icon: Icon(
            _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: const Color(0xFF00DC78),
            size: 28,
          ),
          onPressed: _playing ? _pause : _play,
        ),
        const SizedBox(width: 4),
        // Frame counter
        Text(
          'Frame ${_frameIdx + 1} / $total  •  ${frame.msDelta}ms',
          style: const TextStyle(color: Color(0xFF2A4A6A), fontSize: 11, fontFamily: 'monospace'),
        ),
        const Spacer(),
        // Action label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1828),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF0F2030)),
          ),
          child: Text(
            _actionName(frame.action),
            style: const TextStyle(color: Color(0xFF4A7FA8), fontSize: 10, letterSpacing: 1),
          ),
        ),
        const SizedBox(width: 8),
      ]),
    ]);
  }

  String _actionName(int action) {
    const names = {
      0: 'UNKNOWN', 1: 'STANDING', 2: 'SITTING', 3: 'LYING',
      4: 'BENDING', 5: 'FALLEN',   6: 'STRUGGLING',
    };
    return names[action] ?? 'ACT $action';
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _AlertSkeletonPainter extends CustomPainter {
  final AlertFrame frame;
  const _AlertSkeletonPainter({required this.frame});

  // Build a lookup map: joint index → joint
  Map<int, AlertJoint> get _jointMap =>
      {for (final j in frame.joints) j.index: j};

  // Alert coordinates use the same camera-mounted-90°-CW transform
  Offset _toDisplay(AlertJoint j, Size size) => Offset(
    j.y * size.width,
    (1.0 - j.x) * size.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final map = _jointMap;

    // Draw bones
    for (int bi = 0; bi < _kBones.length; bi++) {
      final ai = _kBones[bi][0];
      final ci = _kBones[bi][1];
      final ja = map[ai];
      final jc = map[ci];
      if (ja == null || jc == null) continue;
      if (ja.confidence < 0.1 || jc.confidence < 0.1) continue;

      canvas.drawLine(
        _toDisplay(ja, size),
        _toDisplay(jc, size),
        Paint()
          ..color      = _segColor(bi).withOpacity(0.85)
          ..strokeWidth = 2.5
          ..strokeCap  = StrokeCap.round
          ..style      = PaintingStyle.stroke,
      );
    }

    // Draw joint dots
    for (final j in frame.joints) {
      if (j.confidence < 0.1) continue;
      final pt   = _toDisplay(j, size);
      final base = const Color(0xFF00FFCC);
      canvas.drawCircle(pt, 7.0, Paint()..color = base.withOpacity(0.12));
      canvas.drawCircle(pt, 3.5, Paint()..color = base);
    }
  }

  @override
  bool shouldRepaint(_AlertSkeletonPainter old) => old.frame != frame;
}