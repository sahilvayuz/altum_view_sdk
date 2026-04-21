// ─────────────────────────────────────────────────────────────────────────────
// features/calibration/presentation/providers/calibration_provider.dart
//
// Drives the calibration UI:
//   • Run full calibration flow
//   • Load previous calibration records
//   • Re-calibrate (same as full flow)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:altum_view_sdk/features/calibration/domain/models/calibration_model.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/calibration_repository.dart';

class CalibrationProvider extends ChangeNotifier {
  final CalibrationRepository _repo;
  CalibrationProvider(this._repo);

  ViewState<void>                      calibrationState    = const IdleState();
  ViewState<List<CalibrationRecordModel>> previousState    = const IdleState();
  Uint8List?                           previewImageBytes;
  String                               statusMessage       = '';

  List<CalibrationRecordModel> get previousCalibrations =>
      previousState is SuccessState<List<CalibrationRecordModel>>
          ? (previousState as SuccessState<List<CalibrationRecordModel>>).data
          : [];

  String? previousCalibrationImage;

  // ── Run full calibration ───────────────────────────────────────────────────

  Future<void> runCalibration(int cameraId) async {
    calibrationState = const LoadingState();
    statusMessage    = 'Starting calibration…';
    notifyListeners();
    try {
      // Fetch preview image to show in UI during calibration
      final token = _repo.generatePreviewToken();
      statusMessage = 'Capturing preview image…';
      notifyListeners();

      await _repo.enablePreview(token);
      previewImageBytes = await _repo.getPreviewImage(
        cameraId: cameraId,
        token:    token,
      );
      notifyListeners();

      statusMessage = 'Detecting floor…';
      notifyListeners();
      await _repo.calibrate(cameraId);

      statusMessage = 'Saving background…';
      notifyListeners();
      await _repo.saveBackground(cameraId);

      calibrationState = const SuccessState(null);
      statusMessage    = 'Calibration complete ✅';
    } catch (e) {
      calibrationState = ErrorState(e.toString());
      statusMessage    = 'Calibration failed: $e';
    }
    notifyListeners();
  }

  // ── Re-calibrate ───────────────────────────────────────────────────────────

  Future<void> reCalibrate(int cameraId) async {
    calibrationState  = const IdleState();
    previewImageBytes = null;
    notifyListeners();
    await runCalibration(cameraId);
  }

  // ── Load previous calibrations ─────────────────────────────────────────────

  Future<void> loadPreviousCalibrations(int cameraId) async {
    previousState = const LoadingState();
    notifyListeners();
    try {
      final records = await _repo.getPreviousCalibrations(cameraId);
      previousCalibrationImage = records.first.backgroundUrl;
      previousState = SuccessState(records);
    } catch (e) {
      previousState = ErrorState(e.toString());
    }
    notifyListeners();
  }
}