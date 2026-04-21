// ─────────────────────────────────────────────────────────────────────────────
// features/calibration/data/sources/calibration_remote_data_source.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:altum_view_sdk/core/services/ble_services.dart';
import 'package:altum_view_sdk/features/calibration/domain/models/calibration_model.dart';

abstract interface class CalibrationRemoteDataSource {
  String generatePreviewToken();

  Future<void> enablePreview({
    required String token,
    required String serialNumber,
  });

  Future<Uint8List?> getPreviewImage({
    required int    cameraId,
    required String token,
  });

  Future<void> calibrate(int cameraId);
  Future<void> saveBackground(int cameraId);
  Future<List<CalibrationRecordModel>> getPreviousCalibrations(int cameraId);
}

class CalibrationRemoteDataSourceImpl implements CalibrationRemoteDataSource {
  final DioClient  _client;
  final BleService _ble;

  const CalibrationRemoteDataSourceImpl({
    required DioClient  client,
    required BleService bleService,
  })  : _client = client,
        _ble    = bleService;

  // ── Step 1 ─────────────────────────────────────────────────────────────────

  @override
  String generatePreviewToken() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return ts.substring(ts.length - 10);
  }

  // ── Step 2 — BLE /TOKEN ────────────────────────────────────────────────────
  //
  // ROOT CAUSE of the missing ACK:
  //   The camera firmware disconnects BLE as soon as it joins WiFi + MQTT.
  //   So when calibration runs, the BLE link is already dead.
  //   The write in sendCommand() succeeds silently on Android even on a
  //   dead connection, but _onRawData() never fires → no ACK → timeout.
  //
  // FIX:
  //   connectToCalibrationDevice() scans and reconnects BLE fresh.
  //   Only then do we send /TOKEN (ack-only, no result packet follows).
  //   After the ACK we immediately disconnect — HTTP handles steps 3-5.

  @override
  Future<void> enablePreview({
    required String token,
    required String serialNumber,
  }) async {
    log('📡 Reconnecting BLE for calibration /TOKEN…');
    await _ble.connectToCalibrationDevice(serialNumber);
    log('✅ BLE reconnected');

    await _ble.enableCalibrationPreview(token); // sendAndWaitAck internally

    await _ble.disconnect();
    log('📴 BLE disconnected — HTTP steps follow');

    await Future.delayed(const Duration(seconds: 2)); // camera settle time
  }

  // ── Step 3 — Preview image ─────────────────────────────────────────────────
  //
  // FIX: Use _client.getBytes() instead of a naked Dio() instance.
  // The old code did `Dio().get(url)` which has NO auth headers → 401.
  // _client.getBytes() goes through the same _AuthInterceptor as every
  // other request, so the Bearer token is attached automatically.

  @override
  Future<Uint8List?> getPreviewImage({
    required int    cameraId,
    required String token,
  }) async {
    try {
      final path = '${ApiConstants.cameraView(cameraId)}?preview_token=$token';
      final resp = await _client.getBytes(path);

      if (resp.statusCode == 200 && resp.data != null) {
        // The API returns base64-encoded image data, not raw bytes.
        // Convert the bytes → string → base64 decode → actual image bytes.
        final base64String = String.fromCharCodes(resp.data!);
        final imageBytes   = base64Decode(base64String);
        log('🖼️  Preview: ${imageBytes.length} bytes (decoded from base64)');
        return imageBytes;
      }
      log('⚠️  Preview: unexpected status ${resp.statusCode}');
      return null;
    } catch (e) {
      log('❌ Preview fetch failed: $e');
      return null;
    }
  }

  // ── Step 4 — Calibrate ─────────────────────────────────────────────────────

  @override
  Future<void> calibrate(int cameraId) async {
    await Future.delayed(const Duration(seconds: 2));
    await _client.get(ApiConstants.cameraCalibrate(cameraId));
    log('✅ Calibration done');
  }

  // ── Step 5 — Save background ───────────────────────────────────────────────

  @override
  Future<void> saveBackground(int cameraId) async {
    await _client.get(ApiConstants.cameraFloormask(cameraId));
    log('✅ Background saved');
  }

  // ── Previous calibrations ──────────────────────────────────────────────────

  @override
  Future<List<CalibrationRecordModel>> getPreviousCalibrations(
      int cameraId) async {
    try {
      final resp = await _client.get(ApiConstants.cameraBackground(cameraId));
      final url  = resp.data['data']?['background_url'] as String?;
      if (url == null || url.isEmpty) return [];
      return [
        CalibrationRecordModel(
          backgroundUrl: url,
          calibratedAt:  DateTime.now(),
        ),
      ];
    } catch (e) {
      log('⚠️  getPreviousCalibrations error: $e');
      return [];
    }
  }
}