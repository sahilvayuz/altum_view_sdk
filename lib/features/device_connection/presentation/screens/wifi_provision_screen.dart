// ─────────────────────────────────────────────────────────────────────────────
// features/device_connection/presentation/screens/wifi_provision_screen.dart
//
// WiFi network selection + password → DeviceConnectionProvider.submitWifi().
// Shows progress steps and final success/failure.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/device_connection/presentation/controller/device_connection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../../../rooms/domain/models/room_model.dart';

class WifiProvisionScreen extends StatefulWidget {
  final BluetoothDevice device;
  final RoomModel room;
  final String deviceName;

  const WifiProvisionScreen({
    super.key,
    required this.device,
    required this.room,
    required this.deviceName,
  });

  @override
  State<WifiProvisionScreen> createState() => _WifiProvisionScreenState();
}

class _WifiProvisionScreenState extends State<WifiProvisionScreen> {
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Trigger WiFi list fetch via provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceConnectionProvider>().startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceConnectionProvider>(
      builder: (context, provider, _) {
        // ── Success state ─────────────────────────────────────────────────
        if (provider.step == SetupStep.success) {
          return _SuccessScreen(
            deviceName: widget.deviceName,
            onDone: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
          );
        }

        // ── Error state ───────────────────────────────────────────────────
        if (provider.step == SetupStep.error && _submitted) {
          return _ErrorScreen(
            message: provider.statusMessage,
            onRetry: () {
              setState(() => _submitted = false);
              provider.reset();
            },
          );
        }

        // ── Progress state ────────────────────────────────────────────────
        if (provider.step == SetupStep.progress) {
          return _ProgressScreen(message: provider.statusMessage);
        }

        // ── Input form ────────────────────────────────────────────────────
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Wi-Fi Setup',
                style:
                TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.chevron_back,
                  color: AppTheme.primary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.wifi,
                          color: AppTheme.primary, size: 36),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Connect to Wi-Fi',
                    style: TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${widget.deviceName}" will use this network to go online.',
                    style: const TextStyle(
                      color: AppTheme.onSurfaceSub,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Nearby networks ───────────────────────────────────────
                  if (provider.wifiList.isNotEmpty) ...[
                    const Text(
                      'NEARBY NETWORKS',
                      style: TextStyle(
                        color: AppTheme.onSurfaceSub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: provider.wifiList.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final ssid = provider.wifiList[i];
                          return GestureDetector(
                            onTap: () =>
                            _ssidCtrl.text = ssid,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.primary.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.wifi,
                                      color: AppTheme.primary, size: 14),
                                  const SizedBox(width: 6),
                                  Text(ssid,
                                      style: const TextStyle(
                                          color: AppTheme.onSurface,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── SSID field ────────────────────────────────────────────
                  const Text('Network Name (SSID)',
                      style: TextStyle(
                        color: AppTheme.onSurfaceSub,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ssidCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      hintText: 'Wi-Fi network name',
                      prefixIcon: Icon(CupertinoIcons.wifi,
                          color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Password field ────────────────────────────────────────
                  const Text('Password',
                      style: TextStyle(
                        color: AppTheme.onSurfaceSub,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Wi-Fi password',
                      prefixIcon: const Icon(CupertinoIcons.lock,
                          color: AppTheme.primary),
                      suffixIcon: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          _obscurePass
                              ? CupertinoIcons.eye
                              : CupertinoIcons.eye_slash,
                          color: AppTheme.onSurfaceSub,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Submit button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final ssid = _ssidCtrl.text;
                        final pass = _passCtrl.text;
                        if (ssid.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter the network name')),
                          );
                          return;
                        }
                        setState(() => _submitted = true);
                        await provider.submitWifi(ssid, pass);
                      },
                      child: const Text('Connect Camera'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Progress Screen ──────────────────────────────────────────────────────────

class _ProgressScreen extends StatelessWidget {
  final String message;
  const _ProgressScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Setting up your camera',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.onSurfaceSub,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'This may take up to 90 seconds.\nPlease keep the app open.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.onSurfaceSub,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Success Screen ───────────────────────────────────────────────────────────

class _SuccessScreen extends StatelessWidget {
  final String deviceName;
  final VoidCallback onDone;

  const _SuccessScreen({required this.deviceName, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.checkmark_circle_fill,
                    color: AppTheme.success, size: 56),
              ),
              const SizedBox(height: 32),
              const Text(
                'Camera is Live! 🎉',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '"$deviceName" connected successfully\nand is now streaming to the server.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.onSurfaceSub,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error Screen ──────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.xmark_circle_fill,
                    color: AppTheme.error, size: 56),
              ),
              const SizedBox(height: 32),
              const Text(
                'Setup Failed',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.onSurfaceSub,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Cancel Setup',
                    style: TextStyle(color: AppTheme.onSurfaceSub)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}