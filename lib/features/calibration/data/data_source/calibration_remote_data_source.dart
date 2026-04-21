// ─────────────────────────────────────────────────────────────────────────────
// features/calibration/data/sources/calibration_remote_data_source.dart
//
// All HTTP + BLE calls for the calibration flow.
//
// Full flow (unchanged from altum_view_controller.dart):
//   Step 1 — generatePreviewToken()         [pure helper, no network]
//   Step 2 — enableCalibrationPreview()     [BLE /TOKEN command]
//   Step 3 — getPreviewImage()              [HTTP GET preview image bytes]
//   Step 4 — calibrateCamera()              [HTTP GET /cameras/:id/calibrate]
//   Step 5 — saveBackground()               [HTTP GET /cameras/:id/floormask/switch]
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'dart:typed_data';

import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:altum_view_sdk/core/services/ble_services.dart';
import 'package:altum_view_sdk/features/calibration/domain/models/calibration_model.dart';

abstract interface class CalibrationRemoteDataSource {
  String             generatePreviewToken();
  Future<void>       enablePreview(String token);
  Future<Uint8List?> getPreviewImage({required int cameraId, required String token});
  Future<void>       calibrate(int cameraId);
  Future<void>       saveBackground(int cameraId);
  Future<List<CalibrationRecordModel>> getPreviousCalibrations(int cameraId);
}

class CalibrationRemoteDataSourceImpl implements CalibrationRemoteDataSource {
  final DioClient  _client;
  final BleService _ble;

  CalibrationRemoteDataSourceImpl({
    required DioClient  client,
    required BleService bleService,
  })  : _client = client,
        _ble    = bleService;

  // ── Step 1 — Token (pure, no network) ─────────────────────────────────────

  @override
  String generatePreviewToken() {
    final rand = DateTime.now().millisecondsSinceEpoch.toString();
    return rand.substring(rand.length - 10); // 10-digit token
  }

  // ── Step 2 — BLE /TOKEN command ────────────────────────────────────────────

  @override
  Future<void> enablePreview(String token) =>
      _ble.enableCalibrationPreview(token);

  // ── Step 3 — Preview image ─────────────────────────────────────────────────

  @override
  Future<Uint8List?> getPreviewImage({
    required int    cameraId,
    required String token,
  }) async {
    try {
      final resp = await _client.get(
        ApiConstants.cameraView(cameraId),
        queryParameters: {'preview_token': token},
      );
      // Dio returns image bytes as List<int> when responseType=bytes;
      // handled via raw Dio call for binary content.
      final rawResp = await _client.getBytes(
        '${ApiConstants.baseUrl}${ApiConstants.cameraView(cameraId)}?preview_token=$token',
      );
      if (rawResp.statusCode == 200 && rawResp.data != null) {
        log('🖼️  Preview image fetched (${rawResp.data!.length} bytes)');
        return Uint8List.fromList(rawResp.data!);
      }
      return null;
    } catch (e) {
      log('❌ Preview fetch failed: $e');
      return null;
    }
  }

  // ── Step 4 — Calibrate ─────────────────────────────────────────────────────

  @override
  Future<void> calibrate(int cameraId) async {
    await _client.get(ApiConstants.cameraCalibrate(cameraId));
    log('✅ Calibration (floor detection) done');
  }

  // ── Step 5 — Save background ───────────────────────────────────────────────

  @override
  Future<void> saveBackground(int cameraId) async {
    await _client.get(ApiConstants.cameraFloormask(cameraId));
    log('✅ Background saved');
  }

  // ── Previous calibrations (new feature) ───────────────────────────────────

  @override
  Future<List<CalibrationRecordModel>> getPreviousCalibrations(int cameraId) async {
    try {
      final resp = await _client.get(ApiConstants.cameraBackground(cameraId));
      final url  = resp.data['data']?['background_url'] as String?;
      if (url == null || url.isEmpty) return [];

      // Return a single record representing the current background
      return [
        CalibrationRecordModel(
          backgroundUrl: url,
          calibratedAt:  DateTime.now(), // API doesn't return timestamp for background
        )
      ];
    } catch (e) {
      log('⚠️  getPreviousCalibrations error: $e');
      return [];
    }
  }
}