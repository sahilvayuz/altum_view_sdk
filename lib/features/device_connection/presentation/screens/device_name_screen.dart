// ─────────────────────────────────────────────────────────────────────────────
// features/device_connection/presentation/screens/device_name_screen.dart
//
// Step 1: User gives the camera a friendly name.
// Step 2: Navigates to WifiProvisionScreen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/device_connection/presentation/screens/wifi_provision_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../rooms/domain/models/room_model.dart';

class DeviceNameScreen extends StatefulWidget {
  final BluetoothDevice device;
  final RoomModel room;

  const DeviceNameScreen({
    super.key,
    required this.device,
    required this.room,
  });

  @override
  State<DeviceNameScreen> createState() => _DeviceNameScreenState();
}

class _DeviceNameScreenState extends State<DeviceNameScreen> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Name Your Camera',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.chevron_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Illustration ────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.camera_fill,
                        color: AppTheme.primary, size: 44),
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Give your camera a name',
                  style: TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose something descriptive like "Front Door" or "Living Room Corner".',
                  style: TextStyle(
                    color: AppTheme.onSurfaceSub,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Name field ───────────────────────────────────────────────
                TextFormField(
                  controller: _ctrl,
                  autofocus: true,
                  style: const TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 17,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Front Door',
                    prefixIcon:
                    Icon(CupertinoIcons.tag, color: AppTheme.primary),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ── Device info chip ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.bluetooth,
                          color: AppTheme.onSurfaceSub, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.device.platformName.isNotEmpty
                              ? widget.device.platformName
                              : widget.device.remoteId.toString(),
                          style: const TextStyle(
                            color: AppTheme.onSurfaceSub,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(CupertinoIcons.checkmark_circle_fill,
                          color: AppTheme.success, size: 16),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Continue button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WifiProvisionScreen(
                            device: widget.device,
                            room: widget.room,
                            deviceName: _ctrl.text.trim(),
                          ),
                        ),
                      );
                    },
                    child: const Text('Continue to Wi-Fi Setup'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}