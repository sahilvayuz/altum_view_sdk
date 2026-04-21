// ─────────────────────────────────────────────────────────────────────────────
// features/device_settings/presentation/screens/device_settings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/design_system/app_theme.dart';
import 'package:altum_view_sdk/features/device_settings/presentation/controllers/device_settings_provider.dart';
import 'package:altum_view_sdk/shared/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../camera/domain/models/camera_model.dart';
import 'package:altum_view_sdk/core/state/view_state.dart';

class DeviceSettingsScreen extends StatefulWidget {
  final CameraModel camera;
  const DeviceSettingsScreen({super.key, required this.camera});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceSettingsProvider>().loadSettings(widget.camera.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Detection Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.chevron_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<DeviceSettingsProvider>(
        builder: (context, provider, _) {
          if (provider.settingsState is LoadingState) {
            return const Center(
                child:
                CircularProgressIndicator(color: AppTheme.primary));
          }

          if (provider.settings == null) {
            return EmptyState(
              icon: CupertinoIcons.slider_horizontal_3,
              title: 'Settings unavailable',
              subtitle: 'Could not load camera settings.',
              buttonLabel: 'Retry',
              onButton: () => provider.loadSettings(widget.camera.id),
            );
          }

          final s = provider.settings!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'DETECTION'),
                CardGroup(
                  children: [
                    // _SwitchRow(
                    //   icon: CupertinoIcons.person_fill,
                    //   label: 'Person Detection',
                    //   value: s.personDetectionEnabled ?? true,
                    //   onChanged: (v) {
                    //     final updated = s.copyWith(personDetectionEnabled: v);
                    //     provider.saveSettings(widget.camera.id, updated);
                    //   },
                    // ),
                    // _SwitchRow(
                    //   icon: CupertinoIcons.hand_raised_fill,
                    //   label: 'Fall Detection',
                    //   value: s.fallDetectionEnabled ?? true,
                    //   onChanged: (v) {
                    //     final updated = s.copyWith(fallDetectionEnabled: v);
                    //     provider.saveSettings(widget.camera.id, updated);
                    //   },
                    // ),
                    // _SwitchRow(
                    //   icon: CupertinoIcons.exclamationmark_shield_fill,
                    //   label: 'Wandering Detection',
                    //   value: s.wanderingDetectionEnabled ?? false,
                    //   onChanged: (v) {
                    //     final updated =
                    //     s.copyWith(wanderingDetectionEnabled: v);
                    //     provider.saveSettings(widget.camera.id, updated);
                    //   },
                    // ),
                  ],
                ),

                const SizedBox(height: 24),
                SectionHeader(title: 'SENSITIVITY'),
                CardGroup(
                  children: [
                    // _SliderRow(
                    //   label: 'Detection Confidence',
                    //   value: (s.detectionConfidence ?? 0.7).toDouble(),
                    //   min: 0.0,
                    //   max: 1.0,
                    //   onChanged: (v) {
                    //     final updated =
                    //     s.copyWith(detectionConfidence: v);
                    //     provider.saveSettings(widget.camera.id, updated);
                    //   },
                    // ),
                  ],
                ),

                const SizedBox(height: 24),
                SectionHeader(title: 'NOTIFICATIONS'),
                CardGroup(
                  children: [
                    // _SwitchRow(
                    //   icon: CupertinoIcons.bell_fill,
                    //   label: 'Push Notifications',
                    //   value: s.pushNotificationsEnabled ?? true,
                    //   onChanged: (v) {
                    //     final updated =
                    //     s.copyWith(pushNotificationsEnabled: v);
                    //     provider.saveSettings(widget.camera.id, updated);
                    //   },
                    // ),
                  ],
                ),

                // Save state feedback
                const SizedBox(height: 16),
                if (provider.saveState is LoadingState)
                  const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary),
                        ),
                        SizedBox(width: 10),
                        Text('Saving…',
                            style: TextStyle(color: AppTheme.onSurfaceSub)),
                      ],
                    ),
                  )
                else if (provider.saveState is SuccessState)
                  const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.checkmark_circle_fill,
                            color: AppTheme.success, size: 16),
                        SizedBox(width: 8),
                        Text('Saved',
                            style: TextStyle(color: AppTheme.success)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary, size: 20),
      title: Text(label,
          style: const TextStyle(color: AppTheme.onSurface, fontSize: 15)),
      trailing: CupertinoSwitch(
        value: value,
        activeColor: AppTheme.primary,
        onChanged: onChanged,
      ),
    );
  }
}

class _SliderRow extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_SliderRow> createState() => _SliderRowState();
}

class _SliderRowState extends State<_SliderRow> {
  late double _v;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label,
                  style: const TextStyle(
                      color: AppTheme.onSurface, fontSize: 15)),
              Text('${(_v * 100).toInt()}%',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: _v,
            min: widget.min,
            max: widget.max,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.surfaceCard2,
            onChanged: (v) => setState(() => _v = v),
            onChangeEnd: widget.onChanged,
          ),
        ],
      ),
    );
  }
}