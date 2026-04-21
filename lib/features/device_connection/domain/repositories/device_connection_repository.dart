// ─────────────────────────────────────────────────────────────────────────────
// features/device_connection/domain/repositories/device_connection_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/features/device_connection/domain/models/device_setup_result_model.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

abstract interface class DeviceConnectionRepository {
  // ── Phase 1 — Scan & connect ──────────────────────────────────────────────
  Future<void>              startScan(void Function(BluetoothDevice) onDeviceFound);
  Future<void>              connectToDevice(BluetoothDevice device);
  Future<Map<String, dynamic>> getDeviceInfo();
  String?                   get deviceSerialNumber;
  String?                   get firmwareVersion;
  Future<String>            getBluetoothToken(String serial);
  Future<List<String>>      getWifiList();
  Future<List<dynamic>>     getRoomsForSetup();

  // ── Phase 2 — WiFi provisioning ───────────────────────────────────────────
  Future<Map<String, dynamic>>  disconnectFromPreviousNetwork(String token);
  Future<Map<String, dynamic>>  setServer(String token);
  Future<CameraSetupResultModel> createCamera({
    required String serial,
    required String firmwareVersion,
    required int    roomId,
  });
  Future<Map<String, dynamic>> setWifi({
    required String token,
    required String ssid,
    required String password,
    required String mqttPasscode,
    required String groupId,
  });
}