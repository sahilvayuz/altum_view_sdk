// ─────────────────────────────────────────────────────────────────────────────
// features/camera/presentation/screens/camera_detail_screen.dart
//
// Central hub for a single camera. Navigates to:
//   Calibration, Device Settings, Alerts, Live Stream, Call, WiFi change.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/alerts/presentation/screens/alert_screen.dart';
import 'package:altum_view_sdk/features/calibration/presentation/screens/calibration_screen.dart';
import 'package:altum_view_sdk/features/device_settings/presentation/screens/device_settings_screen.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/screens/skeleton_stream_screen.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../camera/domain/models/camera_model.dart';

class CameraDetailScreen extends StatelessWidget {
  final CameraModel camera;
  const CameraDetailScreen({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    final isOnline = camera.isOnline ?? false;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.background,
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Row(
                children: [
                  SizedBox(width: 8),
                  Icon(CupertinoIcons.chevron_back, color: AppTheme.primary, size: 20),
                ],
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient bg
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primary.withOpacity(0.3),
                          AppTheme.background,
                        ],
                      ),
                    ),
                  ),
                  // Camera icon
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),
                        Icon(
                          CupertinoIcons.camera_fill,
                          size: 60,
                          color: isOnline
                              ? AppTheme.primary
                              : AppTheme.onSurfaceSub,
                        ),
                        const SizedBox(height: 12),
                        isOnline
                            ? StatusBadge.online()
                            : StatusBadge.offline(),
                      ],
                    ),
                  ),
                ],
              ),
              title: Text(
                camera.friendlyName ?? 'Camera ${camera.id}',
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Quick info ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CardGroup(
                    children: [
                      _InfoRow(
                        icon: CupertinoIcons.barcode,
                        label: 'Serial',
                        value: camera.serialNumber ?? '—',
                      ),
                      _InfoRow(
                        icon: CupertinoIcons.info_circle,
                        label: 'Firmware',
                        value: camera.firmwareVersion ?? '—',
                      ),
                      _InfoRow(
                        icon: CupertinoIcons.wifi,
                        label: 'Wi-Fi',
                        value: camera.id.toString() ?? '—',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Actions ────────────────────────────────────────────────
                SectionHeader(title: 'CAMERA CONTROLS'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.4,
                    children: [
                      _ActionCard(
                        icon: CupertinoIcons.play_rectangle_fill,
                        label: 'Live View',
                        color: AppTheme.success,
                        enabled: isOnline,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SkeletonStreamScreen(
                              cameraId: camera.id,
                              serialNumber: camera.serialNumber ?? '',
                            ),
                          ),
                        ),
                      ),
                      _ActionCard(
                        icon: CupertinoIcons.bell_fill,
                        label: 'Alerts',
                        color: AppTheme.warning,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AlertsScreen(cameraId: camera.id),
                          ),
                        ),
                      ),
                      _ActionCard(
                        icon: CupertinoIcons.layers_alt_fill,
                        label: 'Calibrate',
                        color: AppTheme.primary,
                        enabled: isOnline,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CalibrationScreen(camera: camera),
                          ),
                        ),
                      ),
                      _ActionCard(
                        icon: CupertinoIcons.slider_horizontal_3,
                        label: 'Settings',
                        color: const Color(0xFFAF52DE),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DeviceSettingsScreen(camera: camera),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary, size: 20),
      title: Text(label,
          style: const TextStyle(
              color: AppTheme.onSurfaceSub, fontSize: 13)),
      trailing: Text(
        value,
        style: const TextStyle(
          color: AppTheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 26),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}