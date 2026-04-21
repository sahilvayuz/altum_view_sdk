// ─────────────────────────────────────────────────────────────────────────────
// features/device_connection/data/models/device_setup_result_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class CameraSetupResultModel {
  final int    cameraId;
  final String mqttPasscode;

  const CameraSetupResultModel({
    required this.cameraId,
    required this.mqttPasscode,
  });
}