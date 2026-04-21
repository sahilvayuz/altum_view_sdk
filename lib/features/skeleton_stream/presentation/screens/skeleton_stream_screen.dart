// ─────────────────────────────────────────────────────────────────────────────
// features/skeleton_stream/presentation/screens/skeleton_stream_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/app/service_locator.dart';
import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/controllers/skeleton_stream_provider.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../domain/models/skeleton_model.dart';
import 'package:altum_view_sdk/core/state/view_state.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SkeletonStreamProvider>().startStream();
    });
  }

  @override
  void dispose() {
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
          // ── Error ─────────────────────────────────────────────────────────
          if (provider.streamState is ErrorState) {
            return Center(
              child: EmptyState(
                icon: CupertinoIcons.exclamationmark_triangle,
                title: 'Stream Error',
                subtitle: (provider.streamState as ErrorState).message,
                buttonLabel: 'Retry',
                onButton: provider.startStream,
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

          // ── Streaming / Idle ──────────────────────────────────────────────
          return Stack(
            children: [
              // ── Background image ──────────────────────────────────────────
              if (provider.backgroundImage != null)
                Positioned.fill(
                  child: Image.memory(
                    provider.backgroundImage!,
                    fit: BoxFit.contain,
                  ),
                )
              else
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0xFF0A0A0A),
                    child: Center(
                      child: Text(
                        'Waiting for frame…',
                        style: TextStyle(color: AppTheme.onSurfaceSub),
                      ),
                    ),
                  ),
                ),

              // ── Skeleton overlay ──────────────────────────────────────────
              // persons is List<List<SkeletonJoint>> — non-nullable, safe to check .isNotEmpty
              if (provider.latestFrame != null &&
                  provider.latestFrame!.persons.isNotEmpty)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SkeletonPainter(provider.latestFrame!),
                  ),
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
                        // persons is non-nullable — NO ?. operator needed
                        _HudStat(
                          label: 'Persons',
                          value: '${provider.latestFrame!.persons.length}',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton painter
//
// Uses SkeletonJoint.displayX (= 1.0 - x) to flip camera→screen space.
// Skips joints at (0,0) — no-data sentinel from the parser.
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonPainter extends CustomPainter {
  final SkeletonFrame frame;
  _SkeletonPainter(this.frame);

  // 18-joint AltumView bone connections
  static const List<List<int>> _bones = [
    [0, 1],   // hip centre → spine
    [1, 2],   // spine → chest
    [2, 3],   // chest → head
    [3, 4],   // head → head top
    [2, 5],   // chest → left shoulder
    [5, 6],   // left shoulder → left elbow
    [6, 7],   // left elbow → left wrist
    [2, 8],   // chest → right shoulder
    [8, 9],   // right shoulder → right elbow
    [9, 10],  // right elbow → right wrist
    [0, 11],  // hip → left hip
    [11, 12], // left hip → left knee
    [12, 13], // left knee → left ankle
    [0, 14],  // hip → right hip
    [14, 15], // right hip → right knee
    [15, 16], // right knee → right ankle
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bonePaint = Paint()
      ..color = AppTheme.primary.withOpacity(0.85)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // frame.persons is List<List<SkeletonJoint>> — always non-null
    for (final joints in frame.persons) {
      if (joints.isEmpty) continue;

      // Draw bones
      for (final bone in _bones) {
        final ai = bone[0];
        final bi = bone[1];
        if (ai >= joints.length || bi >= joints.length) continue;

        final ja = joints[ai];
        final jb = joints[bi];

        // (0,0) means no data for this joint — skip
        if (ja.x == 0.0 && ja.y == 0.0) continue;
        if (jb.x == 0.0 && jb.y == 0.0) continue;

        canvas.drawLine(
          Offset(ja.displayX * size.width, ja.y * size.height),
          Offset(jb.displayX * size.width, jb.y * size.height),
          bonePaint,
        );
      }

      // Draw joint dots
      for (final j in joints) {
        if (j.x == 0.0 && j.y == 0.0) continue;
        canvas.drawCircle(
          Offset(j.displayX * size.width, j.y * size.height),
          4.5,
          jointPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => old.frame != frame;
}

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