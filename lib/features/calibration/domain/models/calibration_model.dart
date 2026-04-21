// ─────────────────────────────────────────────────────────────────────────────
// features/calibration/data/models/calibration_model.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

/// Represents a single previous calibration record shown in the
/// "Previous Calibrations" UI panel.
class CalibrationRecordModel {
  final String    backgroundUrl;
  final DateTime  calibratedAt;
  Uint8List?      backgroundImageBytes; // populated lazily after download

  CalibrationRecordModel({
    required this.backgroundUrl,
    required this.calibratedAt,
    this.backgroundImageBytes,
  });
}