// ─────────────────────────────────────────────────────────────────────────────
// features/device_connection/presentation/screens/bluetooth_scan_screen.dart
//
// BLE scanner. Discovered devices list → tap to open DeviceNameScreen.
// Uses DeviceConnectionProvider.startScan().
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/device_connection/presentation/controller/device_connection_provider.dart';
import 'package:altum_view_sdk/features/device_connection/presentation/screens/device_name_screen.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../rooms/domain/models/room_model.dart';

class BluetoothScanScreen extends StatefulWidget {
  final RoomModel room;
  const BluetoothScanScreen({super.key, required this.room});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen>
    with SingleTickerProviderStateMixin {
  final List<BluetoothDevice> _discovered = [];
  bool _scanning = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startScan();
  }

  void _startScan() async {
    setState(() {
      _scanning = true;
      _discovered.clear();
    });

    // Real integration: provider calls FlutterBluePlus internally.
    // Here we wire the onDeviceFound callback to update local list.
    await context.read<DeviceConnectionProvider>().startScan();

    // Listen to FlutterBluePlus scan results for display
    FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final d = r.device;
        if (!_discovered.any((x) => x.remoteId == d.remoteId)) {
          setState(() => _discovered.add(d));
        }
      }
    });

    // Stop showing spinner after 15 s
    await Future.delayed(const Duration(seconds: 15));
    if (mounted) setState(() => _scanning = false);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Add Device',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.xmark, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Radar animation ───────────────────────────────────────────────
          const SizedBox(height: 16),
          _RadarWidget(pulseCtrl: _pulseCtrl, scanning: _scanning),
          const SizedBox(height: 8),
          Text(
            _scanning ? 'Scanning for Altum cameras…' : 'Scan complete',
            style: const TextStyle(
              color: AppTheme.onSurfaceSub,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // ── Device list ───────────────────────────────────────────────────
          SectionHeader(
            title: 'NEARBY DEVICES',
            actionLabel: _scanning ? null : 'Rescan',
            onAction: _startScan,
          ),

          Expanded(
            child: _discovered.isEmpty
                ? Center(
              child: _scanning
                  ? const CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2)
                  : const EmptyState(
                icon: CupertinoIcons.bluetooth,
                title: 'No devices found',
                subtitle:
                'Make sure your camera is in pairing mode (LED blinking blue).',
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _discovered.length,
              itemBuilder: (context, i) =>
                  _BleDeviceTile(
                    device: _discovered[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceNameScreen(
                          device: _discovered[i],
                          room: widget.room,
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Radar animation ──────────────────────────────────────────────────────────

class _RadarWidget extends StatelessWidget {
  final AnimationController pulseCtrl;
  final bool scanning;

  const _RadarWidget({required this.pulseCtrl, required this.scanning});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse rings
          if (scanning) ...[
            for (int i = 0; i < 3; i++)
              AnimatedBuilder(
                animation: pulseCtrl,
                builder: (_, __) {
                  final delay = i * 0.3;
                  final t =
                  ((pulseCtrl.value + delay) % 1.0);
                  return Opacity(
                    opacity: (1 - t) * 0.4,
                    child: Container(
                      width: 80 + (t * 80),
                      height: 80 + (t * 80),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
          // Center icon
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.bluetooth,
                color: AppTheme.primary, size: 30),
          ),
        ],
      ),
    );
  }
}

// ── BLE Device Tile ─────────────────────────────────────────────────────────

class _BleDeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onTap;

  const _BleDeviceTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = device.platformName.isNotEmpty
        ? device.platformName
        : 'Unknown Device';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.camera_fill,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.remoteId.toString(),
                      style: const TextStyle(
                        color: AppTheme.onSurfaceSub,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Connect',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}