// ─────────────────────────────────────────────────────────────────────────────
// features/device_connection/data/repositories/device_connection_repository_impl.dart
//
// Orchestrates the full 2-phase setup flow:
//   Phase 1 — Scan → connect BLE → get info → cloud token → WiFi list
//   Phase 2 — Disconnect prev → set server → register camera → /SET WiFi
//
// This is a direct 1-for-1 extraction of the logic in SetupController and
// altum_view_controller.dart. No business logic is changed.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';

import 'package:altum_view_sdk/core/services/ble_services.dart';
import 'package:altum_view_sdk/features/device_connection/data/data_source_implimentation/camera_setup_remote_data_source.dart';
import 'package:altum_view_sdk/features/device_connection/domain/models/device_setup_result_model.dart';
import 'package:altum_view_sdk/features/device_connection/domain/repositories/device_connection_repository.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';


class DeviceConnectionRepositoryImpl implements DeviceConnectionRepository {
  final BleService                    _ble;
  final CameraSetupRemoteDataSource   _cloud;

  DeviceConnectionRepositoryImpl({
    required BleService                  bleService,
    required CameraSetupRemoteDataSource cloudSource,
  })  : _ble   = bleService,
        _cloud = cloudSource;

  // ── Phase 1 ────────────────────────────────────────────────────────────────

  @override
  Future<void> startScan(void Function(BluetoothDevice) onDeviceFound) =>
      _ble.startScan(onDeviceFound);

  @override
  Future<void> connectToDevice(BluetoothDevice device) =>
      _ble.connectToDevice(device);

  @override
  Future<Map<String, dynamic>> getDeviceInfo() async {
    final result = await _ble.getDeviceInfo();
    log('✅ /GET info: serial=${_ble.deviceSerialNumber}  fw=${_ble.firmwareVersion}');
    return result;
  }

  @override
  String? get deviceSerialNumber => _ble.deviceSerialNumber;

  @override
  String? get firmwareVersion => _ble.firmwareVersion;

  @override
  Future<String> getBluetoothToken(String serial) =>
      _cloud.getBluetoothToken(serial);

  @override
  Future<List<String>> getWifiList() async {
    _ble.deviceWifiList.clear();
    await _ble.getWifiList();
    return List.from(_ble.deviceWifiList);
  }

  // ── Phase 2 ────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> disconnectFromPreviousNetwork(String token) =>
      _ble.disconnectFromPreviousNetwork(token);

  @override
  Future<Map<String, dynamic>> setServer(String token) =>
      _ble.setServer(token);

  @override
  Future<CameraSetupResultModel> createCamera({
    required String serial,
    required String firmwareVersion,
    required int    roomId,
  }) =>
      _cloud.createCamera(
        serial:          serial,
        firmwareVersion: firmwareVersion,
        roomId:          roomId,
      );

  @override
  Future<Map<String, dynamic>> setWifi({
    required String token,
    required String ssid,
    required String password,
    required String mqttPasscode,
    required String groupId,
  }) =>
      _ble.setWifi(
        token:        token,
        ssid:         ssid,
        password:     password,
        mqttPasscode: mqttPasscode,
        groupId:      groupId,
      );

  @override
  Future<List<dynamic>> getRoomsForSetup() => _cloud.getRoomsForSetup();
}

