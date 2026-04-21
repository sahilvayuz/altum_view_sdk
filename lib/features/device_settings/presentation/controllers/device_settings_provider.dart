// ─────────────────────────────────────────────────────────────────────────────
// features/device_settings/presentation/providers/device_settings_provider.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:altum_view_sdk/features/device_settings/domain/models/device_settings_model.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/device_settings_repository.dart';

class DeviceSettingsProvider extends ChangeNotifier {
  final DeviceSettingsRepository _repo;
  DeviceSettingsProvider(this._repo);

  ViewState<DeviceSettingsModel> settingsState = const IdleState();
  ViewState<void>                saveState     = const IdleState();

  DeviceSettingsModel? get settings =>
      settingsState is SuccessState<DeviceSettingsModel>
          ? (settingsState as SuccessState<DeviceSettingsModel>).data
          : null;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadSettings(int cameraId) async {
    settingsState = const LoadingState();
    notifyListeners();
    try {
      final data    = await _repo.getSettings(cameraId);
      settingsState = SuccessState(data);
    } catch (e) {
      settingsState = ErrorState(e.toString());
    }
    notifyListeners();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> saveSettings(int cameraId, DeviceSettingsModel updated) async {
    saveState = const LoadingState();
    notifyListeners();
    try {
      await _repo.updateSettings(cameraId, updated);
      settingsState = SuccessState(updated);
      saveState     = const SuccessState(null);
    } catch (e) {
      saveState = ErrorState(e.toString());
    }
    notifyListeners();
  }
}