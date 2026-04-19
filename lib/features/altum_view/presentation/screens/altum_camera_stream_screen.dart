// ─────────────────────────────────────────────────────────────────────────────
// altum_skeleton_stream_page.dart
//
// HOW TO NAVIGATE HERE:
//
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => AltumSkeletonStreamPage(
//       cameraId:     11237,
//       serialNumber: '230C4C2056C9D0EE',
//       accessToken:  myBearerToken,
//     ),
//   ));
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../controllers/altum_view_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The AltumView camera is physically mounted rotated 90° clockwise.
// This means:
//   • The background JPEG is rotated 90° clockwise (portrait image from a
//     landscape-mounted camera).
//   • The skeleton X/Y coordinates are in the ROTATED camera space.
//
// To display correctly on a 16:9 landscape canvas we must:
//   1. Rotate the background image 90° counter-clockwise to un-rotate it.
//   2. Transform skeleton (x, y) from rotated camera space → display space:
//        displayX = y          (camera Y becomes display X)
//        displayY = 1.0 - x   (camera X becomes display Y, flipped)
//
// The horizontal mirror (displayX = 1.0 - x) that was in SkeletonJoint
// is REMOVED — the rotation transform handles orientation correctly.
// ─────────────────────────────────────────────────────────────────────────────

class AltumSkeletonStreamPage extends StatefulWidget {
  final int cameraId;
  final String serialNumber;
  final String accessToken;

  const AltumSkeletonStreamPage({
    super.key,
    required this.cameraId,
    required this.serialNumber,
    required this.accessToken,
  });

  @override
  State<AltumSkeletonStreamPage> createState() => _AltumStreamState();
}

class _AltumStreamState extends State<AltumSkeletonStreamPage>
    with SingleTickerProviderStateMixin {
  late AltumSkeletonStreamManager _manager;
  StreamSubscription<SkeletonFrame>? _sub;
  SkeletonFrame? _lastFrame;

  String _status = 'Connecting…';
  bool _loading = true;
  bool _hasError = false;
  String _errorMsg = '';

  Timer? _clearTimer;

  late AnimationController _pulse;
  late Animation<double> _pulseVal;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseVal = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    _manager = AltumSkeletonStreamManager(
      accessToken: widget.accessToken,
      cameraId: widget.cameraId,
      serialNumber: widget.serialNumber,
    );

    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _status = 'Connecting…';
    });

    await _sub?.cancel();
    _sub = null;

    try {
      await _manager.start();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Live';
      });

      _sub = _manager.skeletonFrames.listen((frame) {
        _clearTimer?.cancel();
        if (mounted) setState(() => _lastFrame = frame);

        _clearTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _lastFrame = null);
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
        _status = 'Error';
        _errorMsg = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clearTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07101E),
      body: SafeArea(
        child: Column(children: [
          _topBar(),
          Expanded(child: _body()),
          _footer(),
        ]),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _topBar() {
    final isLive = !_loading && !_hasError;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF0F2030))),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF4A7FA8), size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        AnimatedBuilder(
          animation: _pulseVal,
          builder: (_, __) => Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hasError
                  ? const Color(0xFFFF4040)
                  : isLive
                  ? Color.fromRGBO(0, 220, 120, _pulseVal.value)
                  : const Color(0xFFFFAA00),
              boxShadow: isLive && !_hasError
                  ? [
                BoxShadow(
                    color: Color.fromRGBO(
                        0, 220, 120, _pulseVal.value * 0.4),
                    blurRadius: 8,
                    spreadRadius: 2)
              ]
                  : null,
            ),
          ),
        ),
        Text(
          _status.toUpperCase(),
          style: TextStyle(
            color: _hasError
                ? const Color(0xFFFF4040)
                : isLive
                ? const Color(0xFF00DC78)
                : const Color(0xFF4A7FA8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        const Spacer(),
        _badge(Icons.sensors_rounded, 'ALTUMVIEW', const Color(0xFF2A6FAA)),
        if (_hasError) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _connect,
            child:
            _badge(Icons.refresh_rounded, 'RETRY', const Color(0xFFFF5555)),
          ),
        ],
      ]),
    );
  }

  Widget _badge(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 12),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5)),
    ]),
  );

  // ── Body router ────────────────────────────────────────────────────────────

  Widget _body() {
    if (_loading) return _loadingView();
    if (_hasError) return _errorView();
    return _streamView();
  }

  // ── Stream view ────────────────────────────────────────────────────────────

  Widget _streamView() {
    final count = _lastFrame?.persons.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _chip('CAM', '#${widget.cameraId}'),
          const SizedBox(width: 7),
          _chip('PERSONS', '$count',
              hl: count > 0, hlColor: const Color(0xFF00DC78)),
          const SizedBox(width: 7),
          _chip('RATIO', '16 : 9'),
          const SizedBox(width: 7),
          _chip('JOINTS', '18'),
        ]),
        const SizedBox(height: 12),

        // 16:9 canvas
        Expanded(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _canvas(count),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 66,
          child: _lastFrame != null && _lastFrame!.persons.isNotEmpty
              ? ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _lastFrame!.persons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _PersonCard(
              index: i,
              joints: _lastFrame!.persons[i],
            ),
          )
              : _emptyBar(),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _canvas(int personCount) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: personCount > 0
              ? const Color(0xFF00DC78).withOpacity(0.25)
              : const Color(0xFF0F2030),
          width: personCount > 0 ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(fit: StackFit.expand, children: [
          // ── Background image ───────────────────────────────────────────
          // The camera is mounted rotated 90° clockwise, so the background
          // JPEG arrives rotated. We counter-rotate by 90° CCW (-π/2) to
          // display it upright in the landscape canvas.
          if (_manager.backgroundImage != null)
            _RotatedBackground(imageBytes: _manager.backgroundImage!),

          // Darken overlay
          if (_manager.backgroundImage != null)
            Container(color: Colors.black.withOpacity(0.48)),

          // Dot-grid fallback
          if (_manager.backgroundImage == null)
            CustomPaint(painter: _DotGridPainter()),

          const _Corners(),

          // ── Skeleton overlay ───────────────────────────────────────────
          // _SkeletonPainter uses _rotatedOffset() which converts the
          // rotated-camera coords → landscape display coords.
          if (_lastFrame != null && !_lastFrame!.isEmpty)
            CustomPaint(painter: _SkeletonPainter(frame: _lastFrame!)),

          if (_lastFrame == null || _lastFrame!.isEmpty) _noPersonOverlay(),
        ]),
      ),
    );
  }

  Widget _noPersonOverlay() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.person_search_rounded,
          color: Color(0xFF152030), size: 40),
      const SizedBox(height: 10),
      const Text('AWAITING DETECTION',
          style: TextStyle(
              color: Color(0xFF152030),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5)),
    ]),
  );

  Widget _emptyBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF08141F),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF0F2030)),
    ),
    child: const Row(children: [
      Icon(Icons.person_off_outlined, color: Color(0xFF152A3A), size: 16),
      SizedBox(width: 10),
      Text('No persons detected',
          style: TextStyle(color: Color(0xFF213040), fontSize: 12)),
    ]),
  );

  Widget _chip(String label, String val,
      {bool hl = false, Color hlColor = const Color(0xFF2A6FAA)}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1828),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color:
              hl ? hlColor.withOpacity(0.5) : const Color(0xFF0F2030)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label  ',
              style: const TextStyle(
                  color: Color(0xFF2A4A6A),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          Text(val,
              style: TextStyle(
                  color: hl ? hlColor : const Color(0xFF4A7FA8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ]),
      );

  // ── Loading / Error views ──────────────────────────────────────────────────

  Widget _loadingView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedBuilder(
        animation: _pulseVal,
        builder: (_, __) => Opacity(
          opacity: _pulseVal.value,
          child: const Icon(Icons.sensors_rounded,
              color: Color(0xFF2A6FAA), size: 52),
        ),
      ),
      const SizedBox(height: 22),
      const Text('INITIALIZING STREAM',
          style: TextStyle(
              color: Color(0xFF1A4060),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 3.0)),
      const SizedBox(height: 8),
      const Text('Fetching MQTT credentials…',
          style: TextStyle(color: Color(0xFF0F2A3A), fontSize: 11)),
    ]),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child:
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off_rounded,
            color: Color(0xFFFF4040), size: 52),
        const SizedBox(height: 20),
        const Text('CONNECTION FAILED',
            style: TextStyle(
                color: Color(0xFFFF4040),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5)),
        const SizedBox(height: 10),
        Text(_errorMsg,
            style:
            const TextStyle(color: Color(0xFF4A2020), fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _connect,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2A6FAA)),
                borderRadius: BorderRadius.circular(6)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded,
                  color: Color(0xFF2A6FAA), size: 16),
              SizedBox(width: 8),
              Text('RETRY',
                  style: TextStyle(
                      color: Color(0xFF2A6FAA),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0)),
            ]),
          ),
        ),
      ]),
    ),
  );

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _footer() {
    final ts = _lastFrame?.receivedAt;
    final t = ts != null
        ? '${_p(ts.hour)}:${_p(ts.minute)}:${_p(ts.second)}'
        '.${ts.millisecond.toString().padLeft(3, '0')}'
        : '--:--:--.---';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(children: [
        const Icon(Icons.schedule_rounded, color: Color(0xFF0F2030), size: 11),
        const SizedBox(width: 5),
        Text('Last frame  $t',
            style: const TextStyle(
                color: Color(0xFF0F2030),
                fontSize: 10,
                fontFamily: 'monospace')),
        const Spacer(),
        const Text('MQTT · WSS · TLS',
            style: TextStyle(
                color: Color(0xFF0A1828), fontSize: 9, letterSpacing: 1.5)),
      ]),
    );
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

// ═════════════════════════════════════════════════════════════════════════════
// ROTATED BACKGROUND
//
// The camera JPEG is rotated 90° CW (portrait orientation).
// We un-rotate it by rotating 90° CCW inside the landscape canvas.
// ═════════════════════════════════════════════════════════════════════════════

class _RotatedBackground extends StatelessWidget {
  final Uint8List imageBytes;
  const _RotatedBackground({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return Transform(
        alignment: Alignment.center,
        // Rotate 90° counter-clockwise to correct the camera mounting rotation
        transform: Matrix4.rotationZ(-math.pi / 2),
        child: SizedBox(
          // After rotating, width and height swap — fill the container
          width: h,
          height: w,
          child: Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      );
    });
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SKELETON PAINTER
//
// 18-joint AltumView model:
//    0=Nose   1=Neck
//    2=RShoulder  3=RElbow   4=RWrist
//    5=LShoulder  6=LElbow   7=LWrist
//    8=RHip   9=RKnee  10=RAnkle
//   11=LHip  12=LKnee  13=LAnkle
//   14=REye  15=LEye   16=REar  17=LEar
//
// Coordinate transform for 90° CW camera mounting:
//   The camera coord system has (0,0) at top-left of the rotated image.
//   To map into our landscape display (16:9):
//     displayX = joint.y          (camera Y → display X)
//     displayY = 1.0 - joint.x   (camera X → display Y, flipped)
// ═════════════════════════════════════════════════════════════════════════════

const List<List<int>> _kBones = [
  [0, 1], [1, 2], [1, 5],
  [2, 3], [3, 4], [5, 6], [6, 7],
  [1, 8], [1, 11], [8, 9], [9, 10],
  [11, 12], [12, 13],
  [0, 14], [0, 15], [14, 16], [15, 17],
];

const List<Color> _kPersonColors = [
  Color(0xFF00FFCC),
  Color(0xFFFF6B9D),
  Color(0xFFFFD700),
  Color(0xFF4A9EFF),
];

Color _segmentColor(int bi) {
  if (bi == 0 || bi >= 13) return const Color(0xFF00FFCC); // head/face
  if (bi <= 6) return const Color(0xFF4A9EFF);             // arms
  if (bi <= 8) return const Color(0xFFFFD700);             // torso
  return const Color(0xFFFF6B9D);                          // legs
}

/// Converts raw camera joint coordinates to display Offset on the canvas.
///
/// The camera is mounted 90° clockwise, so the coordinate axes are rotated.
/// Camera space:  x = 0 (bottom of real scene) → 1 (top of real scene)
///                y = 0 (left of real scene)    → 1 (right of real scene)
/// Display space (16:9 landscape):
///                X = camera Y
///                Y = 1 - camera X   (flip so head is at top of display)
Offset _toDisplay(SkeletonJoint j, Size size) {
  return Offset(
    j.y * size.width,          // camera Y → display X
    (1.0 - j.x) * size.height, // camera X (flipped) → display Y
  );
}

class _SkeletonPainter extends CustomPainter {
  final SkeletonFrame frame;
  const _SkeletonPainter({required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    for (int pi = 0; pi < frame.persons.length; pi++) {
      final joints = frame.persons[pi];
      final base = _kPersonColors[pi % _kPersonColors.length];

      // Draw bones
      for (int bi = 0; bi < _kBones.length; bi++) {
        final ai = _kBones[bi][0], ci = _kBones[bi][1];
        if (ai >= joints.length || ci >= joints.length) continue;

        final ja = joints[ai];
        final jc = joints[ci];

        // Skip joints the camera marks as undetected (both coords == 0)
        if (ja.x == 0.0 && ja.y == 0.0) continue;
        if (jc.x == 0.0 && jc.y == 0.0) continue;

        canvas.drawLine(
          _toDisplay(ja, size),
          _toDisplay(jc, size),
          Paint()
            ..color = (pi == 0 ? _segmentColor(bi) : base).withOpacity(0.85)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }

      // Draw joint dots
      for (final j in joints) {
        if (j.x == 0.0 && j.y == 0.0) continue;
        final pt = _toDisplay(j, size);
        canvas.drawCircle(pt, 7.0, Paint()..color = base.withOpacity(0.12));
        canvas.drawCircle(pt, 3.5, Paint()..color = base);
      }
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => old.frame != frame;
}

// ═════════════════════════════════════════════════════════════════════════════
// SUPPORTING PAINTERS & WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF0D2030).withOpacity(0.8);
    for (double x = 28; x < size.width; x += 28) {
      for (double y = 28; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 0.7, p);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _Corners extends StatelessWidget {
  const _Corners();

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF1A3A5C);
    const s = 14.0;
    Widget mk(bool fx, bool fy, AlignmentGeometry a) => Align(
      alignment: a,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Transform.scale(
          scaleX: fx ? -1 : 1,
          scaleY: fy ? -1 : 1,
          child: SizedBox(
              width: s,
              height: s,
              child: CustomPaint(painter: _CornerPainter(c))),
        ),
      ),
    );
    return Stack(fit: StackFit.expand, children: [
      mk(false, false, Alignment.topLeft),
      mk(true, false, Alignment.topRight),
      mk(false, true, Alignment.bottomLeft),
      mk(true, true, Alignment.bottomRight),
    ]);
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), p);
    canvas.drawLine(Offset.zero, Offset(0, size.height), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _PersonCard extends StatelessWidget {
  final int index;
  final List<SkeletonJoint> joints;
  const _PersonCard({required this.index, required this.joints});

  @override
  Widget build(BuildContext context) {
    final color = _kPersonColors[index % _kPersonColors.length];

    // Use the same _toDisplay logic for the position indicator
    // Hip centre in display space
    double cx = 0.5, cy = 0.5;
    if (joints.length > 11) {
      // Average of R-Hip (8) and L-Hip (11) in display coords
      cx = (joints[8].y + joints[11].y) / 2;
      cy = ((1.0 - joints[8].x) + (1.0 - joints[11].x)) / 2;
    }

    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF081420),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Container(
                width: 7,
                height: 7,
                decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('PERSON ${index + 1}',
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 5),
          Text(
            'X ${cx.toStringAsFixed(3)}   Y ${cy.toStringAsFixed(3)}',
            style: const TextStyle(
                color: Color(0xFF2A4A6A),
                fontSize: 10,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}