// ─────────────────────────────────────────────────────────────────────────────
// features/calibration/presentation/screens/calibration_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/calibration/presentation/controllers/calibration_provider.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../camera/domain/models/camera_model.dart';
import 'package:altum_view_sdk/core/state/view_state.dart';

class CalibrationScreen extends StatefulWidget {
  final CameraModel camera;
  const CalibrationScreen({super.key, required this.camera});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<CalibrationProvider>()
          .loadPreviousCalibrations(widget.camera.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Calibration',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.chevron_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<CalibrationProvider>(
        builder: (context, provider, _) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Preview image ──────────────────────────────────────
                    if (provider.previewImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          provider.previewImageBytes!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(CupertinoIcons.camera,
                              color: AppTheme.onSurfaceSub, size: 40),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // ── Status message ─────────────────────────────────────
                    if (provider.statusMessage.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          provider.statusMessage,
                          style: const TextStyle(
                              color: AppTheme.primary, fontSize: 14),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ── Actions ────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(CupertinoIcons.layers_alt_fill,
                                size: 18),
                            label: const Text('Start Calibration'),
                            onPressed:
                            provider.calibrationState is LoadingState
                                ? null
                                : () => provider
                                .runCalibration(widget.camera.id),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: const Icon(CupertinoIcons.refresh,
                              size: 18, color: AppTheme.primary),
                          label: const Text('Re-calibrate',
                              style: TextStyle(color: AppTheme.primary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                          ),
                          onPressed:
                          provider.calibrationState is LoadingState
                              ? null
                              : () => provider
                              .reCalibrate(widget.camera.id),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Previous calibrations ──────────────────────────────
                    SectionHeader(title: 'PREVIOUS CALIBRATIONS'),
                    if (provider.previousCalibrations.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No previous calibrations found.',
                            style: TextStyle(color: AppTheme.onSurfaceSub),
                          ),
                        ),
                      )
                    else
                      CardGroup(
                        children: provider.previousCalibrations
                            .map((rec) => ListTile(
                          leading: const Icon(
                              CupertinoIcons.checkmark_circle,
                              color: AppTheme.success,
                              size: 20),
                          title: Text(
                            rec.calibratedAt.toString() ??
                                'Calibration',
                            style: const TextStyle(
                                color: AppTheme.onSurface,
                                fontSize: 14),
                          ),
                          trailing: Text(
                             'Status: N/A',
                            style: const TextStyle(
                                color: AppTheme.onSurfaceSub,
                                fontSize: 12),
                          ),
                        ))
                            .toList(),
                      ),
                  ],
                ),
              ),

              // ── Loading overlay ────────────────────────────────────────────
              if (provider.calibrationState is LoadingState)
                LoadingOverlay(message: provider.statusMessage),
            ],
          );
        },
      ),
    );
  }
}