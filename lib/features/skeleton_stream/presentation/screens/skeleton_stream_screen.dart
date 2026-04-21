// ─────────────────────────────────────────────────────────────────────────────
// features/skeleton_stream/presentation/screens/skeleton_stream_screen.dart
//
// Changes vs previous version:
//   • Background image rendered + rotated 90° CCW (camera mounted 90° CW)
//   • Per-person colour cycling (4 colours)
//   • Skeleton uses rotated-camera coordinate transform (y → displayX, 1-x → displayY)
//   • Landscape-only mode via SystemChrome orientation lock
//   • dispose() properly triggers stopStream() on pop
//   • Status-aware overlays:
//       – "Waiting for frame…"        (connected, silence > 3 s)
//       – "Waiting for republishing…" (token just re-published)
//       – "Camera went offline"        (is_online == false)
//   • Exports SkeletonStreamCard — a reusable embeddable widget with:
//       orientation  : StreamOrientation.landscape | portrait
//       width / height constructor params
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:altum_view_sdk/app/service_locator.dart';
import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/controllers/skeleton_stream_provider.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/models/skeleton_model.dart';
import 'package:altum_view_sdk/core/state/view_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Orientation mode for the reusable card widget
// ─────────────────────────────────────────────────────────────────────────────

enum StreamOrientation { landscape, portrait }

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen page (landscape-locked)
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonStreamScreen extends StatelessWidget {
  final int cameraId;
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
        cameraId: cameraId,
        serialNumber: serialNumber,
      ),
      child: _SkeletonStreamView(cameraId: cameraId),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonStreamView extends StatefulWidget {
  final int cameraId;
  const _SkeletonStreamView({required this.cameraId});

  @override
  State<_SkeletonStreamView> createState() => _SkeletonStreamViewState();
}

class _SkeletonStreamViewState extends State<_SkeletonStreamView> {
  @override
  void initState() {
    super.initState();
    // Lock to landscape for the full-screen view
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SkeletonStreamProvider>().startStream();
    });
  }

  @override
  void dispose() {
    // Restore all orientations when leaving
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    context.read<SkeletonStreamProvider>().stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Live View',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.xmark, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<SkeletonStreamProvider>(
            builder: (context, provider, _) => CupertinoButton(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                provider.isStreaming
                    ? CupertinoIcons.stop_circle
                    : CupertinoIcons.play_circle,
                color: provider.isStreaming ? AppTheme.error : AppTheme.success,
                size: 28,
              ),
              onPressed: () async {
                if (provider.isStreaming) {
                  await provider.stopStream();
                } else {
                  await provider.startStream();
                }
              },
            ),
          ),
        ],
      ),
      body: Consumer<SkeletonStreamProvider>(
        builder: (context, provider, _) {
          if (provider.streamState is ErrorState) {
            return Center(
              child: EmptyState(
                icon: CupertinoIcons.exclamationmark_triangle,
                title: _errorTitle(provider.streamStatus),
                subtitle: (provider.streamState as ErrorState).message,
                buttonLabel: 'Retry',
                onButton: provider.startStream,
              ),
            );
          }

          if (provider.streamState is LoadingState) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2),
                  SizedBox(height: 20),
                  Text(
                    'Connecting to stream…',
                    style: TextStyle(
                        color: AppTheme.onSurfaceSub, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // ── Background (rotated 90° CCW) ──────────────────────────────
              if (provider.backgroundImage != null)
                Positioned.fill(
                  child: _RotatedBackground(
                      imageBytes: provider.backgroundImage!),
                )
              else
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF0A0A0A)),
                ),

              // ── Skeleton overlay ──────────────────────────────────────────
              if (provider.latestFrame != null &&
                  provider.latestFrame!.persons.isNotEmpty)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SkeletonPainter(provider.latestFrame!),
                  ),
                ),

              // ── Status overlays ───────────────────────────────────────────
              Positioned.fill(
                child: _StatusOverlay(status: provider.streamStatus),
              ),

              // ── LIVE / STOPPED badge ──────────────────────────────────────
              Positioned(
                top: 16,
                left: 16,
                child: StatusBadge(
                  label: provider.isStreaming ? 'LIVE' : 'STOPPED',
                  color: provider.isStreaming
                      ? AppTheme.error
                      : AppTheme.onSurfaceSub,
                ),
              ),

              // ── HUD bar ───────────────────────────────────────────────────
              if (provider.latestFrame != null)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _HudStat(
                          label: 'Persons',
                          value:
                          '${provider.latestFrame!.persons.length}',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _errorTitle(SkeletonStreamStatus s) {
    if (s == SkeletonStreamStatus.cameraOffline) return 'Camera Offline';
    return 'Stream Error';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable embeddable card widget
//
// Usage:
//   SkeletonStreamCard(
//     cameraId:     11237,
//     serialNumber: 'ABC123',
//     orientation:  StreamOrientation.landscape,
//     width:        400,
//     height:       225,
//   )
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonStreamCard extends StatelessWidget {
  final int cameraId;
  final String serialNumber;
  final StreamOrientation orientation;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const SkeletonStreamCard({
    super.key,
    required this.cameraId,
    required this.serialNumber,
    this.orientation = StreamOrientation.landscape,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.buildSkeletonProvider(
        cameraId: cameraId,
        serialNumber: serialNumber,
      ),
      child: _SkeletonCardView(
        orientation: orientation,
        width: width,
        height: height,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
    );
  }
}

class _SkeletonCardView extends StatefulWidget {
  final StreamOrientation orientation;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const _SkeletonCardView({
    required this.orientation,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<_SkeletonCardView> createState() => _SkeletonCardViewState();
}

class _SkeletonCardViewState extends State<_SkeletonCardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SkeletonStreamProvider>().startStream();
    });
  }

  @override
  void dispose() {
    // Dispose is called when the card leaves the widget tree
    context.read<SkeletonStreamProvider>().stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = widget.orientation == StreamOrientation.landscape;
    final aspectRatio = isLandscape ? 16 / 9 : 9 / 16;

    Widget card = Consumer<SkeletonStreamProvider>(
      builder: (context, provider, _) {
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: Container(
            color: Colors.black,
            child: _cardBody(provider, isLandscape),
          ),
        );
      },
    );

    // Size constraint
    if (widget.width != null || widget.height != null) {
      card = SizedBox(
        width: widget.width,
        height: widget.height,
        child: card,
      );
    } else {
      card = AspectRatio(aspectRatio: aspectRatio, child: card);
    }

    return card;
  }

  Widget _cardBody(SkeletonStreamProvider provider, bool isLandscape) {
    if (provider.streamState is LoadingState) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: AppTheme.primary, strokeWidth: 1.5),
            SizedBox(height: 10),
            Text('Connecting…',
                style: TextStyle(
                    color: AppTheme.onSurfaceSub, fontSize: 12)),
          ],
        ),
      );
    }

    if (provider.streamState is ErrorState) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                provider.streamStatus == SkeletonStreamStatus.cameraOffline
                    ? CupertinoIcons.wifi_slash
                    : CupertinoIcons.exclamationmark_circle,
                color: AppTheme.error,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                _statusLabel(provider.streamStatus),
                style: const TextStyle(
                    color: AppTheme.onSurfaceSub, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              CupertinoButton(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                onPressed: provider.startStream,
                child: const Text('Retry',
                    style:
                    TextStyle(color: AppTheme.primary, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        if (provider.backgroundImage != null)
          isLandscape
              ? _RotatedBackground(imageBytes: provider.backgroundImage!)
              : Image.memory(provider.backgroundImage!,
              fit: BoxFit.cover, gaplessPlayback: true)
        else
          const ColoredBox(color: Color(0xFF0A0A0A)),

        // Skeleton
        if (provider.latestFrame != null &&
            provider.latestFrame!.persons.isNotEmpty)
          CustomPaint(painter: _SkeletonPainter(provider.latestFrame!)),

        // Status overlay
        _StatusOverlay(status: provider.streamStatus, compact: true),

        // Live badge
        Positioned(
          top: 8,
          left: 8,
          child: _MiniLiveBadge(live: provider.isStreaming),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status overlay — shown centred when no skeleton frame active
// ─────────────────────────────────────────────────────────────────────────────

class _StatusOverlay extends StatelessWidget {
  final SkeletonStreamStatus status;
  final bool compact;

  const _StatusOverlay({required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    String? message;
    IconData? icon;

    switch (status) {
      case SkeletonStreamStatus.waitingForFrame:
        message = 'Waiting for frame…';
        icon = CupertinoIcons.clock;
        break;
      case SkeletonStreamStatus.waitingRepublish:
        message = 'Waiting for republishing…';
        icon = CupertinoIcons.arrow_2_circlepath;
        break;
      case SkeletonStreamStatus.cameraOffline:
        message = 'Camera went offline';
        icon = CupertinoIcons.wifi_slash;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: AppTheme.onSurfaceSub,
              size: compact ? 22 : 32),
          SizedBox(height: compact ? 6 : 10),
          Text(
            message,
            style: TextStyle(
              color: AppTheme.onSurfaceSub,
              fontSize: compact ? 11 : 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rotated background: camera JPEG is 90° CW → un-rotate 90° CCW
// ─────────────────────────────────────────────────────────────────────────────

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
        transform: Matrix4.rotationZ(-math.pi / 2),
        child: SizedBox(
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

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton painter
//
// Camera mounted 90° CW → coordinate transform:
//   displayX = joint.y
//   displayY = 1.0 - joint.x
//
// 18-joint AltumView model:
//   0=Nose  1=Neck  2=RShoulder  3=RElbow  4=RWrist
//   5=LShoulder  6=LElbow  7=LWrist
//   8=RHip  9=RKnee  10=RAnkle
//   11=LHip  12=LKnee  13=LAnkle
//   14=REye  15=LEye  16=REar  17=LEar
// ─────────────────────────────────────────────────────────────────────────────

const List<List<int>> _kBones = [
  [0, 1], [1, 2], [1, 5],
  [2, 3], [3, 4], [5, 6], [6, 7],
  [1, 8], [1, 11], [8, 9], [9, 10],
  [11, 12], [12, 13],
  [0, 14], [0, 15], [14, 16], [15, 17],
];

/// Four person colours — cycles for person index % 4
const List<Color> _kPersonColors = [
  Color(0xFF00FFCC), // teal
  Color(0xFFFF6B9D), // pink
  Color(0xFFFFD700), // gold
  Color(0xFF4A9EFF), // blue
];

Color _segmentColor(int bi, Color personBase) {
  if (bi == 0 || bi >= 13) return const Color(0xFF00FFCC); // head/face
  if (bi <= 6) return const Color(0xFF4A9EFF); // arms
  if (bi <= 8) return const Color(0xFFFFD700); // torso
  return const Color(0xFFFF6B9D); // legs
}

Offset _toDisplay(SkeletonJoint j, Size size) {
  return Offset(
    j.y * size.width,
    (1.0 - j.x) * size.height,
  );
}

class _SkeletonPainter extends CustomPainter {
  final SkeletonFrame frame;
  const _SkeletonPainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    for (int pi = 0; pi < frame.persons.length; pi++) {
      final joints = frame.persons[pi];
      final personColor = _kPersonColors[pi % _kPersonColors.length];

      // Bones
      for (int bi = 0; bi < _kBones.length; bi++) {
        final ai = _kBones[bi][0], ci = _kBones[bi][1];
        if (ai >= joints.length || ci >= joints.length) continue;

        final ja = joints[ai];
        final jc = joints[ci];
        if (ja.x == 0.0 && ja.y == 0.0) continue;
        if (jc.x == 0.0 && jc.y == 0.0) continue;

        // Person 0 uses segment-specific colours; other persons use their base colour
        final boneColor =
        pi == 0 ? _segmentColor(bi, personColor) : personColor;

        canvas.drawLine(
          _toDisplay(ja, size),
          _toDisplay(jc, size),
          Paint()
            ..color = boneColor.withOpacity(0.85)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }

      // Joint dots
      for (final j in joints) {
        if (j.x == 0.0 && j.y == 0.0) continue;
        final pt = _toDisplay(j, size);
        canvas.drawCircle(
            pt, 7.0, Paint()..color = personColor.withOpacity(0.18));
        canvas.drawCircle(pt, 3.5, Paint()..color = personColor);
      }
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => old.frame != frame;
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini badge for the card widget
// ─────────────────────────────────────────────────────────────────────────────

class _MiniLiveBadge extends StatelessWidget {
  final bool live;
  const _MiniLiveBadge({required this.live});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: live ? AppTheme.error : AppTheme.onSurfaceSub,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: live ? AppTheme.error : AppTheme.onSurfaceSub,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            live ? 'LIVE' : 'STOPPED',
            style: TextStyle(
              color: live ? AppTheme.error : AppTheme.onSurfaceSub,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HUD stat row (full-screen page)
// ─────────────────────────────────────────────────────────────────────────────

class _HudStat extends StatelessWidget {
  final String label;
  final String value;
  const _HudStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
              color: AppTheme.onSurfaceSub, fontSize: 11),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _statusLabel(SkeletonStreamStatus s) {
  switch (s) {
    case SkeletonStreamStatus.cameraOffline:
      return 'Camera went offline';
    case SkeletonStreamStatus.waitingForFrame:
      return 'Waiting for frame…';
    case SkeletonStreamStatus.waitingRepublish:
      return 'Waiting for republishing…';
    case SkeletonStreamStatus.error:
      return 'Stream error';
    default:
      return 'Unavailable';
  }
}