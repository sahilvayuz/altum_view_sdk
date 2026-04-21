// ─────────────────────────────────────────────────────────────────────────────
// features/calibration/data/repositories/calibration_repository_impl.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'dart:typed_data';
import 'package:altum_view_sdk/features/calibration/data/data_source/calibration_remote_data_source.dart';
import 'package:altum_view_sdk/features/calibration/domain/models/calibration_model.dart';

import '../../domain/repositories/calibration_repository.dart';

class CalibrationRepositoryImpl implements CalibrationRepository {
  final CalibrationRemoteDataSource _source;
  CalibrationRepositoryImpl(this._source);

  @override
  String generatePreviewToken() => _source.generatePreviewToken();

  @override
  Future<void> enablePreview(String token) => _source.enablePreview(token);

  @override
  Future<Uint8List?> getPreviewImage({
    required int    cameraId,
    required String token,
  }) =>
      _source.getPreviewImage(cameraId: cameraId, token: token);

  @override
  Future<void> calibrate(int cameraId) => _source.calibrate(cameraId);

  @override
  Future<void> saveBackground(int cameraId) => _source.saveBackground(cameraId);

  @override
  Future<List<CalibrationRecordModel>> getPreviousCalibrations(int cameraId) =>
      _source.getPreviousCalibrations(cameraId);

  // ── Full calibration flow ─────────────────────────────────────────────────
  // Mirrors runFullCalibration() from altum_view_controller.dart exactly.

  @override
  Future<void> runFullCalibration(int cameraId) async {
    try {
      final token = generatePreviewToken();
      await Future.delayed(const Duration(seconds: 2));

      await enablePreview(token);
      await Future.delayed(const Duration(seconds: 2));

      await getPreviewImage(cameraId: cameraId, token: token);
      await Future.delayed(const Duration(seconds: 2));

      await calibrate(cameraId);
      await saveBackground(cameraId);

      log('🎉 Calibration COMPLETED');
    } catch (e) {
      log('❌ Calibration flow failed: $e');
      rethrow;
    }
  }
}