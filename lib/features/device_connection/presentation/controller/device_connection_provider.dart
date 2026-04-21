// ─────────────────────────────────────────────────────────────────────────────
// features/device_connection/presentation/providers/device_connection_provider.dart
//
// Drop-in replacement for SetupController.
// Drives the full BLE + cloud setup flow and exposes clean UI state.
//
// Steps:
//   scan → connecting → [wifi list ready] → wifi → progress → success / error
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';

import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../domain/repositories/device_connection_repository.dart';

enum SetupStep { scan, connecting, wifi, progress, success, error }

class DeviceConnectionProvider extends ChangeNotifier {
  final DeviceConnectionRepository _repo;
  DeviceConnectionProvider(this._repo);

  // ── UI-facing state ────────────────────────────────────────────────────────
  SetupStep          step         = SetupStep.scan;
  String             statusMessage = '';
  List<String>       wifiList     = [];
  ViewState<void>    setupState   = const IdleState();

  BluetoothDevice?   _device;
  String?            _token;
  String?            _mqttPasscode;
  int?               _roomId;

  // ── Device found — kick off Phase 1 ───────────────────────────────────────

  void onDeviceFound(BluetoothDevice device) async {
    log('📡 Device found → ${device.platformName} (${device.remoteId})');
    _device = device;
    _setStep(SetupStep.connecting, 'Connecting to device…');

    try {
      await _runPhase1();
    } catch (e) {
      log('❌ Phase 1 failed: $e');
      _fail('Setup failed: $e');
    }
  }

  // ── Phase 1: Connect → info → token → WiFi list ───────────────────────────

  Future<void> _runPhase1() async {
    await _repo.connectToDevice(_device!);
    log('✅ BLE connected, MTU negotiated');

    _setStep(SetupStep.connecting, 'Reading device info…');
    await _repo.getDeviceInfo();

    final serial = _repo.deviceSerialNumber;
    if (serial == null) throw Exception('Serial number not returned by /GET info');
    log('✅ Serial: $serial  FW: ${_repo.firmwareVersion}');

    _setStep(SetupStep.connecting, 'Getting permission…');
    _token = await _repo.getBluetoothToken(serial);
    log('✅ Bluetooth token: $_token');

    _setStep(SetupStep.connecting, 'Scanning Wi-Fi…');
    final networks = await _repo.getWifiList();
    if (networks.isEmpty) throw Exception('No Wi-Fi networks returned');

    wifiList = networks;
    log('📶 ${wifiList.length} networks found');

    _setStep(SetupStep.wifi, '');
  }

  // ── Phase 2: WiFi provisioning ─────────────────────────────────────────────

  Future<void> submitWifi(String ssid, String password) async {
    _setStep(SetupStep.progress, 'Connecting to Wi-Fi…');

    if (_token == null) throw Exception('Bluetooth token missing');
    final serial = _repo.deviceSerialNumber;
    if (serial == null) throw Exception('Serial number missing');

    try {
      log('📡 Starting Wi-Fi provisioning — SSID: $ssid');

      // /DISCONNECT
      _setStep(SetupStep.progress, 'Disconnecting previous network…');
      await _repo.disconnectFromPreviousNetwork(_token!);
      log('✅ /DISCONNECT done');

      // /SERVER
      _setStep(SetupStep.progress, 'Setting server…');
      final serverResult = await _repo.setServer(_token!);
      if (serverResult['status'] != 'success') {
        throw Exception('/SERVER failed: ${serverResult['status']}');
      }
      log('✅ /SERVER done');

      // Cloud: pick first room
      _setStep(SetupStep.progress, 'Registering camera…');
      final rooms = await _repo.getRoomsForSetup();
      _roomId = (rooms.first as dynamic).id as int;

      await Future.delayed(const Duration(seconds: 3));

      final cameraResult = await _repo.createCamera(
        serial:          serial,
        firmwareVersion: _repo.firmwareVersion ?? '',
        roomId:          _roomId!,
      );
      _mqttPasscode = cameraResult.mqttPasscode;
      log('✅ Camera registered (roomId=$_roomId  mqtt=$_mqttPasscode)');

      // /SET — may take up to 90 s
      _setStep(SetupStep.progress, 'Sending Wi-Fi credentials…');
      final setResult = await _repo.setWifi(
        token:        _token!,
        ssid:         ssid,
        password:     password,
        mqttPasscode: _mqttPasscode!,
        groupId:      '4528',
      );

      final wifiStatus = setResult['wifi_status'] as String? ?? 'unknown';
      final mqttStatus = setResult['mqtt_status'] as String? ?? 'unknown';
      log('wifi_status=$wifiStatus  mqtt_status=$mqttStatus');

      if (wifiStatus == 'success') {
        _setStep(SetupStep.success, '');
      } else {
        _fail('Wi-Fi connection failed (wifi=$wifiStatus, mqtt=$mqttStatus)');
      }
    } catch (e) {
      log('❌ Phase 2 failed: $e');
      _fail('Setup failed: $e');
    }
  }

  // ── Scan ───────────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    _setStep(SetupStep.scan, 'Scanning for devices…');
    try {
      await _repo.startScan(onDeviceFound);
    } catch (e) {
      _fail(e.toString());
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setStep(SetupStep s, String msg) {
    step          = s;
    statusMessage = msg;
    notifyListeners();
  }

  void _fail(String msg) {
    log('❌ DeviceConnectionProvider → $msg');
    step          = SetupStep.error;
    statusMessage = msg;
    notifyListeners();
  }

  void reset() {
    step          = SetupStep.scan;
    statusMessage = '';
    wifiList      = [];
    _device       = null;
    _token        = null;
    _mqttPasscode = null;
    notifyListeners();
  }
}