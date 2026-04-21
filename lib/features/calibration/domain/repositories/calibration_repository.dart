// ─────────────────────────────────────────────────────────────────────────────
// features/calibration/domain/repositories/calibration_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:altum_view_sdk/features/calibration/domain/models/calibration_model.dart';


abstract interface class CalibrationRepository {
  String             generatePreviewToken();
  Future<void>       enablePreview(String token);
  Future<Uint8List?> getPreviewImage({required int cameraId, required String token});
  Future<void>       calibrate(int cameraId);
  Future<void>       saveBackground(int cameraId);
  Future<List<CalibrationRecordModel>> getPreviousCalibrations(int cameraId);
  Future<void>       runFullCalibration(int cameraId);
}