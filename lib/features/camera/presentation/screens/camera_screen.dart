// ─────────────────────────────────────────────────────────────────────────────
// features/rooms/presentation/screens/devices_screen.dart
//
// Shows cameras inside a room. Tap camera → CameraDetailScreen.
// FAB → Bluetooth scan to add device.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/camera/presentation/controllers/camera_provider.dart';
import 'package:altum_view_sdk/features/camera/presentation/screens/camera_detail_screen.dart';
import 'package:altum_view_sdk/features/device_connection/presentation/screens/device_connection_screen.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../rooms/domain/models/room_model.dart';
import '../../../camera/domain/models/camera_model.dart';
import 'package:altum_view_sdk/core/state/view_state.dart';
class DevicesScreen extends StatefulWidget {
  final RoomModel room;
  const DevicesScreen({super.key, required this.room});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().loadCameras();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: AppTheme.background,
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Row(
                children: [
                  SizedBox(width: 8),
                  Icon(CupertinoIcons.chevron_back,
                      color: AppTheme.primary, size: 20),
                  Text('Rooms',
                      style: TextStyle(color: AppTheme.primary, fontSize: 17)),
                ],
              ),
              onPressed: () => Navigator.pop(context),
            ),
            leadingWidth: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.name,
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // ── Add Device Button ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ElevatedButton.icon(
                  icon: const Icon(CupertinoIcons.add, size: 16),
                  label: const Text('Add Device'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BluetoothScanScreen(room: widget.room),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Consumer<CameraProvider>(
            builder: (context, provider, _) {
              // Filter cameras by roomId
              final cameras = provider.cameras
                  .where((c) => c.roomId == widget.room.id)
                  .toList();

              if (provider.cameraListState is LoadingState) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                );
              }

              if (cameras.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    icon: CupertinoIcons.camera,
                    title: 'No Devices Yet',
                    subtitle:
                    'Tap "Add Device" to pair a camera to this room.',
                    buttonLabel: 'Add Device',
                    onButton: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            BluetoothScanScreen(room: widget.room),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) => _CameraCard(
                      camera: cameras[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CameraDetailScreen(camera: cameras[i]),
                        ),
                      ),
                    ),
                    childCount: cameras.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Camera Card ─────────────────────────────────────────────────────────────

class _CameraCard extends StatelessWidget {
  final CameraModel camera;
  final VoidCallback onTap;

  const _CameraCard({required this.camera, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOnline = camera.isOnline ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ───────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? AppTheme.success.withOpacity(0.15)
                          : AppTheme.surfaceCard2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      CupertinoIcons.camera_fill,
                      color: isOnline
                          ? AppTheme.success
                          : AppTheme.onSurfaceSub,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camera.friendlyName ?? 'Camera ${camera.id}',
                          style: const TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          camera.serialNumber ?? 'Unknown serial',
                          style: const TextStyle(
                            color: AppTheme.onSurfaceSub,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  isOnline
                      ? StatusBadge.online()
                      : StatusBadge.offline(),
                ],
              ),

              // ── Divider + stats row ───────────────────────────────────────
              const SizedBox(height: 14),
              const Divider(height: 0),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Stat(
                    icon: CupertinoIcons.wifi,
                    label: camera.id.toString() ?? '—',
                  ),
                  _Stat(
                    icon: CupertinoIcons.info_circle,
                    label: camera.firmwareVersion ?? '—',
                  ),
                  _Stat(
                    icon: CupertinoIcons.chevron_right,
                    label: 'Details',
                    isAction: true,
                    onTap: onTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isAction;
  final VoidCallback? onTap;

  const _Stat({
    required this.icon,
    required this.label,
    this.isAction = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon,
              size: 14,
              color: isAction ? AppTheme.primary : AppTheme.onSurfaceSub),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isAction ? AppTheme.primary : AppTheme.onSurfaceSub,
              fontSize: 13,
              fontWeight:
              isAction ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}