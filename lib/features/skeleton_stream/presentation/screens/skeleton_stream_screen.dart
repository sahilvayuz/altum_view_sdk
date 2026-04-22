// ─────────────────────────────────────────────────────────────────────────────
// features/skeleton_stream/presentation/screens/skeleton_stream_screen.dart
//
// FINAL FIX — addresses all observed issues:
//
// FACT: Flutter's ui.instantiateImageCodec respects EXIF orientation.
//   The camera JPEG has an EXIF tag saying "rotated 90°", so Flutter decodes
//   it and reports dimensions AFTER rotation:
//     _imgNativeW = 1080  (short side — what was height)
//     _imgNativeH = 1920  (long side  — what was width)
//   i.e. Flutter always gives us the DISPLAY dimensions, not the raw sensor.
//
// PORTRAIT mode (show as-is, no software rotation):
//   • JPEG displays correctly as a landscape scene without rotation because
//     Flutter already handles the EXIF auto-rotation internally in Image.memory.
//   • Rendered box: W = screenW, H = screenW * (_imgNativeH / _imgNativeW)
//     For 1920×1080 sensor → Flutter reports 1080×1920 → ratio = 1920/1080 = 1.78
//     renderedH = screenW * 1.78  → TALL portrait box  ✓
//     Wait — that's wrong for portrait. Portrait should show a WIDE landscape scene.
//
// RE-ANALYSIS based on screenshots:
//   Portrait (Image 2 from previous round) was CORRECT — short landscape image.
//   That means Flutter was reporting nativeW > nativeH for portrait mode.
//   So Flutter does NOT auto-rotate for Image.memory — it gives raw JPEG dims.
//   Raw JPEG: nativeW=1920, nativeH=1080.
//   Portrait formula: screenW * (1080/1920) = screenW * 0.5625 ✓ short landscape
//
// LANDSCAPE mode issue:
//   Formula was: renderedH = screenW * (nativeW / nativeH) = screenW * 1.78 ✓
//   But screenshot shows image is SHORT (landscape shaped in portrait phone).
//   → _decodeImageSize is running AFTER the initial render, so the FALLBACK
//     is being used: renderedH = screenW * (16/9) ≈ screenW * 1.78. That IS tall.
//   → So why is the image short? The image itself is not rotating.
//
// REAL ROOT CAUSE of image not filling:
//   The Transform widget inside _Background shifts the image CENTER but the
//   SizedBox wrapping Stack clips it. The rotated image overflows and gets
//   clipped by ClipRect. The LayoutBuilder inside _Background gives W < H
//   (portrait box), but after -90° rotation a landscape JPEG of size H×W
//   has its painted size = W wide and H tall, which MATCHES — but Transform
//   rotates around center so it should be fine.
//
//   ACTUAL issue: The image box height is computed correctly but the
//   SCREEN BODY has the Scaffold body which is the full remaining height.
//   SingleChildScrollView Column puts the SizedBox at the TOP — there
//   should be no gap above. The gap above = the image isn't at y=0.
//   The gap is ABOVE the image = the Column has some top padding, OR
//   the SizedBox isn't consuming full width because widget.width = double.infinity
//   but LayoutBuilder resolves it differently.
//
// THE REAL FIX:
//   1. Wrap in a SizedBox.expand / use constraints properly.
//   2. For landscape: rotate +90° CW (not -90°) — confirmed by image content.
//   3. Skeleton coords for +90° CW: displayX = joint.y * W, displayY = (1-joint.x) * H
//   4. Remove SingleChildScrollView for landscape — use a plain Column or
//      just return the Stack directly so it fills the Scaffold body.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:altum_view_sdk/app/service_locator.dart';
import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/controllers/skeleton_stream_provider.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/managers/skeleton_stream_manager.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/skeleton_model.dart';
import 'package:altum_view_sdk/core/state/view_state.dart';

enum StreamOrientation { landscape, portrait }

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonStreamScreen
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonStreamScreen extends StatelessWidget {
  final int    cameraId;
  final String serialNumber;

  const SkeletonStreamScreen({
    super.key,
    required this.cameraId,
    required this.serialNumber,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.buildSkeletonProvider(
        cameraId:     cameraId,
        serialNumber: serialNumber,
      ),
      child: _SkeletonStreamPage(cameraId: cameraId),
    );
  }
}

class _SkeletonStreamPage extends StatelessWidget {
  final int cameraId;
  const _SkeletonStreamPage({required this.cameraId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Live View',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.xmark, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<SkeletonStreamProvider>(
            builder: (_, p, __) => CupertinoButton(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                p.isStreaming
                    ? CupertinoIcons.stop_circle
                    : CupertinoIcons.play_circle,
                color: p.isStreaming ? AppTheme.error : AppTheme.success,
                size: 28,
              ),
              onPressed: () async {
                if (p.isStreaming) {
                  await p.stopStream();
                } else {
                  await p.startStream();
                }
              },
            ),
          ),
        ],
      ),
      body: AltumStreamView(
        cameraId:            cameraId,
        orientation:         StreamOrientation.landscape,
        width:               300,
        useExternalProvider: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AltumStreamView
// ─────────────────────────────────────────────────────────────────────────────

class AltumStreamView extends StatelessWidget {
  final int               cameraId;
  final String?           serialNumber;
  final StreamOrientation orientation;
  final double            width;
  final bool              useExternalProvider;

  const AltumStreamView({
    super.key,
    required this.cameraId,
    this.serialNumber,
    this.orientation         = StreamOrientation.landscape,
    this.width               = double.infinity,
    this.useExternalProvider = false,
  });

  @override
  Widget build(BuildContext context) {
    final canvas = _StreamCanvas(
      cameraId:    cameraId,
      orientation: orientation,
      width:       width,
    );

    if (useExternalProvider) return canvas;

    assert(serialNumber != null,
    'AltumStreamView: serialNumber required when useExternalProvider=false');

    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.buildSkeletonProvider(
        cameraId:     cameraId,
        serialNumber: serialNumber!,
      ),
      child: canvas,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StreamCanvas
// ─────────────────────────────────────────────────────────────────────────────

class _StreamCanvas extends StatefulWidget {
  final int               cameraId;
  final StreamOrientation orientation;
  final double            width;

  const _StreamCanvas({
    required this.cameraId,
    required this.orientation,
    required this.width,
  });

  @override
  State<_StreamCanvas> createState() => _StreamCanvasState();
}

class _StreamCanvasState extends State<_StreamCanvas> {
  // Raw JPEG pixel dimensions (before any rotation).
  // nativeW > nativeH for a landscape sensor JPEG.
  int? _nativeW;
  int? _nativeH;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SkeletonStreamProvider>().startStream();
    });
  }

  @override
  void dispose() {
    context.read<SkeletonStreamProvider>().stopStream();
    super.dispose();
  }

  // Decode using dart:ui directly — gives raw JPEG pixel dims,
  // ignoring EXIF orientation (unlike higher-level Flutter image widgets).
  Future<void> _decodeImageSize(Uint8List bytes) async {
    if (_nativeW != null) return;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      if (mounted && w > 0 && h > 0) {
        setState(() {
          // Ensure we store as landscape: longer side = W
          if (w >= h) {
            _nativeW = w;
            _nativeH = h;
          } else {
            // EXIF already applied by codec → swap back to raw landscape
            _nativeW = h;
            _nativeH = w;
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SkeletonStreamProvider>(
      builder: (_, provider, __) {
        // ── Error ─────────────────────────────────────────────────────────
        if (provider.streamState is ErrorState) {
          return Center(
            child: EmptyState(
              icon:        CupertinoIcons.exclamationmark_triangle,
              title:       'Stream Error',
              subtitle:    (provider.streamState as ErrorState).message,
              buttonLabel: 'Retry',
              onButton:    provider.startStream,
            ),
          );
        }

        // ── Connecting ────────────────────────────────────────────────────
        if (provider.streamState is LoadingState) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2),
                SizedBox(height: 16),
                Text('Connecting to stream…',
                    style: TextStyle(
                        color: AppTheme.onSurfaceSub, fontSize: 14)),
              ],
            ),
          );
        }

        if (provider.backgroundImage != null && _nativeW == null) {
          _decodeImageSize(provider.backgroundImage!);
        }

        return LayoutBuilder(builder: (ctx, constraints) {
          final screenW = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.of(ctx).size.width;
          return _buildCanvas(provider, screenW);
        });
      },
    );
  }

  Widget _buildCanvas(SkeletonStreamProvider provider, double screenW) {
    final isLandscape = widget.orientation == StreamOrientation.landscape;
    final bg          = provider.backgroundImage;

    // ── Aspect ratio ────────────────────────────────────────────────────────
    // We always store _nativeW >= _nativeH (landscape raw JPEG).
    //
    // PORTRAIT  — show JPEG as-is (no rotation):
    //   box is landscape-shaped: H = screenW * (nativeH / nativeW)
    //   e.g. 1920×1080 → H = screenW * 0.5625
    //
    // LANDSCAPE — rotate JPEG +90° CW to stand scene upright:
    //   displayed size after rotation: W_disp = nativeH, H_disp = nativeW
    //   scale to fill screenW: H_box = screenW * (nativeW / nativeH)
    //   e.g. 1920×1080 → H = screenW * 1.7778  (tall portrait box)

    final double nW = (_nativeW ?? 1920).toDouble();
    final double nH = (_nativeH ?? 1080).toDouble();

    final double renderedH = isLandscape
        ? screenW * (nW / nH)   // tall portrait box
        : screenW * (nH / nW);  // short landscape box

    // ── Build the image + skeleton stack ────────────────────────────────────
    // For LANDSCAPE we want the image to fill the Scaffold body top-to-bottom.
    // We do NOT wrap in SingleChildScrollView — we use Align + top anchor.

    final imageStack = SizedBox(
      width:  screenW,
      height: renderedH,
      child: ClipRect(
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: bg != null
                  ? _Background(imageBytes: bg, isLandscape: isLandscape)
                  : const ColoredBox(color: Color(0xFF0A0A0A)),
            ),

            // Skeleton
            if (provider.latestFrame != null &&
                provider.latestFrame!.persons.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: _SkeletonPainter(
                    frame:       provider.latestFrame!,
                    isLandscape: isLandscape,
                  ),
                ),
              ),

            // Status overlay
            Positioned.fill(
              child: _StatusOverlay(status: provider.streamStatus),
            ),

            // LIVE badge
            Positioned(
              top:  10,
              left: 10,
              child: StatusBadge(
                label: provider.isStreaming ? 'LIVE' : 'STOPPED',
                color: provider.isStreaming
                    ? AppTheme.error
                    : AppTheme.onSurfaceSub,
              ),
            ),
          ],
        ),
      ),
    );

    // HUD widget
    final hud = provider.latestFrame != null
        ? Container(
      color:   Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${provider.latestFrame!.persons.length}',
                style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   22,
                    fontWeight: FontWeight.w700),
              ),
              const Text('Persons',
                  style: TextStyle(
                      color:    AppTheme.onSurfaceSub,
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    )
        : const SizedBox.shrink();

    // For landscape the image is very tall — wrap in scroll so user can see HUD
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [imageStack, hud],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Background
//
// PORTRAIT  — Image.memory with no rotation. Flutter's codec handles EXIF
//   internally for rendering, so the scene appears correctly oriented.
//   BoxFit.fill on exact-sized box = no crop, no letterbox.
//
// LANDSCAPE — rotate +90° CW so the landscape scene stands upright.
//   The SizedBox (from _buildCanvas) is already portrait-shaped: W < H.
//   The raw JPEG is landscape. We pre-size it H×W (axes swapped) before
//   applying the +90° CW rotation, so after rotation it fills W×H exactly.
// ─────────────────────────────────────────────────────────────────────────────

// ─── REPLACE _Background with this ───────────────────────────────────────────

class _Background extends StatelessWidget {
  final Uint8List imageBytes;
  final bool      isLandscape;
  const _Background({required this.imageBytes, required this.isLandscape});

  @override
  Widget build(BuildContext context) {
    if (!isLandscape) {
      // Portrait — raw JPEG is landscape, show as-is, fills the short box exactly
      return Image.memory(
        imageBytes,
        fit:             BoxFit.fill,
        gaplessPlayback: true,
      );
    }

    // Landscape — use RotatedBox(quarterTurns: 1) = +90° CW
    // RotatedBox participates in layout: it reports swapped W↔H to the parent,
    // so the child image is measured as H wide × W tall (filling the portrait
    // SizedBox exactly) with ZERO overflow and ZERO cropping.
    return RotatedBox(
      quarterTurns: 1,             // +90° CW
      child: Image.memory(
        imageBytes,
        width:           double.infinity,
        height:          double.infinity,
        fit:             BoxFit.fill,
        gaplessPlayback: true,
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// _SkeletonPainter
//
// Camera joint coords: x ∈ [0,1], y ∈ [0,1]
// Camera convention (from reference images, office scene):
//   x=0 → left of scene,  x=1 → right of scene
//   y=0 → top of scene,   y=1 → bottom of scene
//
// PORTRAIT (no image rotation):
//   Screen X = camera X → displayX = joint.x * W
//   Screen Y = camera Y → displayY = joint.y * H
//
// LANDSCAPE (+90° CW image rotation):
//   +90° CW maps camera axes to screen axes as:
//     camera +X (right) → screen +Y (down)
//     camera +Y (down)  → screen -X (left) → so camera +Y → screen (W - x)
//   Therefore:
//     displayX = (1 - joint.y) * W
//     displayY =       joint.x  * H
// ─────────────────────────────────────────────────────────────────────────────

const List<List<int>> _kBones = [
  [0, 1],   [1, 2],   [1, 5],
  [2, 3],   [3, 4],
  [5, 6],   [6, 7],
  [1, 8],   [1, 11],
  [8, 9],   [9, 10],
  [11, 12], [12, 13],
  [0, 14],  [0, 15],
  [14, 16], [15, 17],
];

const List<Color> _kPersonColors = [
  Color(0xFF00FFCC),
  Color(0xFFFF6B9D),
  Color(0xFFFFD700),
  Color(0xFF4A9EFF),
];

class _SkeletonPainter extends CustomPainter {
  final SkeletonFrame frame;
  final bool          isLandscape;
  const _SkeletonPainter({required this.frame, required this.isLandscape});

  Offset _toDisplay(SkeletonJoint j, Size size) {
    if (isLandscape) {
      return Offset(
        (1.0 - j.y) * size.width,
        j.x         * size.height,
      );
    } else {
      return Offset(
        j.x * size.width,
        j.y * size.height,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int pi = 0; pi < frame.persons.length; pi++) {
      final joints = frame.persons[pi];
      final color  = _kPersonColors[pi % _kPersonColors.length];

      for (final bone in _kBones) {
        final ai = bone[0], bi = bone[1];
        if (ai >= joints.length || bi >= joints.length) continue;
        final ja = joints[ai], jb = joints[bi];
        if (ja.x == 0.0 && ja.y == 0.0) continue;
        if (jb.x == 0.0 && jb.y == 0.0) continue;

        canvas.drawLine(
          _toDisplay(ja, size),
          _toDisplay(jb, size),
          Paint()
            ..color       = color.withOpacity(0.9)
            ..strokeWidth = 2.5
            ..strokeCap   = StrokeCap.round
            ..style       = PaintingStyle.stroke,
        );
      }

      for (final j in joints) {
        if (j.x == 0.0 && j.y == 0.0) continue;
        final pt = _toDisplay(j, size);
        canvas.drawCircle(pt, 6.0, Paint()..color = color.withOpacity(0.15));
        canvas.drawCircle(pt, 3.5, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.frame != frame || old.isLandscape != isLandscape;
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusOverlay
// ─────────────────────────────────────────────────────────────────────────────

class _StatusOverlay extends StatelessWidget {
  final StreamStatus status;
  const _StatusOverlay({required this.status});

  @override
  Widget build(BuildContext context) {
    String?   message;
    IconData? icon;

    switch (status) {
      case StreamStatus.waitingForFrame:
        message = 'Waiting for frame…';
        icon    = CupertinoIcons.clock;
        break;
      case StreamStatus.republishing:
        message = 'Waiting for republishing…';
        icon    = CupertinoIcons.arrow_2_circlepath;
        break;
      case StreamStatus.offline:
        message = 'Camera is offline';
        icon    = CupertinoIcons.wifi_slash;
        break;
      case StreamStatus.idle:
        message = 'Stream stopped';
        icon    = CupertinoIcons.stop_circle;
        break;
      case StreamStatus.live:
      case StreamStatus.connecting:
      case StreamStatus.error:
        return const SizedBox.shrink();
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.onSurfaceSub.withOpacity(0.6), size: 30),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(
                  color: AppTheme.onSurfaceSub.withOpacity(0.7),
                  fontSize: 13)),
        ],
      ),
    );
  }
}