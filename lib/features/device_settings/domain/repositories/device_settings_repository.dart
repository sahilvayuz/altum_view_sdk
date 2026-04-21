// ─────────────────────────────────────────────────────────────────────────────
// features/device_settings/domain/repositories/device_settings_repository.dart
// ─────────────────────────────────────────────────────────────────────────────


import 'package:altum_view_sdk/features/device_settings/domain/models/device_settings_model.dart';

abstract interface class DeviceSettingsRepository {
  Future<DeviceSettingsModel> getSettings(int cameraId);
  Future<void>                updateSettings(int cameraId, DeviceSettingsModel settings);
}