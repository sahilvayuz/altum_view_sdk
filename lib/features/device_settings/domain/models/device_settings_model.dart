// ─────────────────────────────────────────────────────────────────────────────
// features/device_settings/data/models/device_settings_model.dart
//
// Maps the camera settings fields shown in the app's Detection Settings screen
// (Sensitivity, Age Filter, etc).
// ─────────────────────────────────────────────────────────────────────────────

class DeviceSettingsModel {
  final String  friendlyName;
  final String  sensitivity;     // "LOW" | "MLD" | "HIGH"
  final bool    ageFilterEnabled;
  final bool    isOnline;
  final bool    isStreaming;

  const DeviceSettingsModel({
    required this.friendlyName,
    required this.sensitivity,
    required this.ageFilterEnabled,
    required this.isOnline,
    required this.isStreaming,
  });

  factory DeviceSettingsModel.fromJson(Map<String, dynamic> j) =>
      DeviceSettingsModel(
        friendlyName:    j['friendly_name']    as String? ?? '',
        sensitivity:     j['sensitivity']      as String? ?? 'MLD',
        ageFilterEnabled: (j['age_filter']     as bool?) ?? false,
        isOnline:        (j['is_online']       as bool?) ?? false,
        isStreaming:     (j['is_streaming']    as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
    'friendly_name': friendlyName,
    'sensitivity':   sensitivity,
    'age_filter':    ageFilterEnabled,
  };

  DeviceSettingsModel copyWith({
    String? friendlyName,
    String? sensitivity,
    bool?   ageFilterEnabled,
  }) =>
      DeviceSettingsModel(
        friendlyName:    friendlyName    ?? this.friendlyName,
        sensitivity:     sensitivity     ?? this.sensitivity,
        ageFilterEnabled: ageFilterEnabled ?? this.ageFilterEnabled,
        isOnline:        isOnline,
        isStreaming:     isStreaming,
      );
}