import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'altum_view_controller.dart';

enum SetupStep { scan, connecting, wifi, progress, success, error }

class SetupController extends ChangeNotifier {
  SetupStep step = SetupStep.scan;
  String status = '';
  List<String> wifiList = [];

  BluetoothDevice? _device;
  String? _token;

  /* ─────────────────────────────────────────
     Device Found → kick off setup
  ───────────────────────────────────────── */

  void onDeviceFound(BluetoothDevice device) async {
    log('📡 BLE device found → ${device.platformName} (${device.remoteId})');

    _device = device;
    step = SetupStep.connecting;
    status = 'Connecting to device…';
    notifyListeners();

    try {
      await _setupDevice();
    } catch (e) {
      log('❌ Setup failed → $e');
      _fail('Setup failed: $e');
    }
  }

  /* ─────────────────────────────────────────
     Phase 1 — Connect and read device info
     Sequence (mirrors client log):
       connect → MTU 517 → /GET info → BT token → /GET network_list
  ───────────────────────────────────────── */

  Future<void> _setupDevice() async {
    // ── Connect + MTU + notifications ─────────────────────
    log('🔗 Connecting to BLE device');
    await connectToDevice(_device!);
    log('✅ BLE connected, MTU negotiated, notifications active');

    // ── /GET info ─────────────────────────────────────────
    status = 'Reading device info…';
    notifyListeners();
    log('📡 Sending /GET info');

    final infoResult = await getDeviceInfo();
    log('✅ /GET info result: $infoResult');

    if (deviceSerialNumber == null) {
      throw Exception('Serial number not returned by /GET info');
    }
    log('✅ Serial: $deviceSerialNumber  FW: $firmwareVersion');

    // ── Cloud: get Bluetooth token ─────────────────────────
    status = 'Getting permission…';
    notifyListeners();
    log('🌐 Requesting Bluetooth token');

    _token = await getBluetoothToken(deviceSerialNumber!);
    log('✅ Bluetooth token: $_token');

    // ── /GET network_list ──────────────────────────────────
    status = 'Scanning Wi-Fi…';
    notifyListeners();
    log('📡 Sending /GET network_list');

    deviceWifiList.clear();
    await getWifiList();

    if (deviceWifiList.isEmpty) {
      throw Exception('No Wi-Fi networks returned');
    }

    wifiList = List.from(deviceWifiList);
    log('📶 ${wifiList.length} Wi-Fi networks found');

    step = SetupStep.wifi;
    notifyListeners();
  }

  /* ─────────────────────────────────────────
     Phase 2 — Wi-Fi provisioning
     Sequence (mirrors client log exactly):
       /DISCONNECT → wait ack+success
       /SERVER     → wait ack+success
       cloud: createCamera
       /SET        → wait ack  (then wait up to 90s for set_network result)
  ───────────────────────────────────────── */

  Future<void> submitWifi(String ssid, String pass) async {
    step = SetupStep.progress;
    status = 'Connecting to Wi-Fi…';
    notifyListeners();

    if (_token == null) throw Exception('Bluetooth token missing');
    if (deviceSerialNumber == null) throw Exception('Serial number missing');

    log('📡 Starting Wi-Fi provisioning');
    log('   SSID: $ssid  (hex: ${toHex(ssid)})');

    // ── /DISCONNECT ───────────────────────────────────────
    log('📡 Sending /DISCONNECT');
    status = 'Disconnecting previous network…';
    notifyListeners();

    final disconnectResult = await disconnectFromPreviousNetwork(_token!);
    log('✅ /DISCONNECT: ${disconnectResult['status']}');

    // ── /SERVER ───────────────────────────────────────────
    log('📡 Sending /SERVER');
    status = 'Setting server…';
    notifyListeners();

    final serverResult = await setServer(_token!);
    log('✅ /SERVER: ${serverResult['status']}');

    if (serverResult['status'] != 'success') {
      throw Exception('/SERVER failed: ${serverResult['status']}');
    }

    // ── Cloud: register camera ────────────────────────────
    log('🌐 Registering camera in cloud');
    status = 'Registering camera…';
    notifyListeners();

    final rooms = await getRooms(accessToken: authToken);
    final roomId = rooms.first.id;

   // final resetResult = await factoryReset(_token ?? '');
   // log('✅ /FACTORY_RESET: ${resetResult['status']}');
    // Give the device time to reset and come back
   // log('⏳ Waiting 3s for device to settle after factory reset...');
    await Future.delayed(const Duration(seconds: 3));

    await createImpendingCamera(
      serial: deviceSerialNumber!,
      firmwareVersion: firmwareVersion ?? '',
      roomId: roomId,
      accessToken: authToken,
    );
    log('✅ Camera registered in cloud (roomId=$roomId)');

    // ── /SET ──────────────────────────────────────────────
    // The camera takes up to ~58 seconds to attempt WiFi and respond.
    // We wait the full 90s as per the API spec.
    log('📡 Sending /SET (ssid=${toHex(ssid)} psk=${toHex(pass)})');
    status = 'Sending Wi-Fi credentials…';
    notifyListeners();

  //  await Future.delayed(Duration(seconds: 8));

    final setResult = await setWifi(
      token: _token!,
      ssid: ssid,
      password: pass,
      groupId: '4528',
    );

    log('✅ /SET result: $setResult');

    final wifiStatus = setResult['wifi_status'] as String? ?? 'unknown';
    final mqttStatus = setResult['mqtt_status'] as String? ?? 'unknown';

    log('   wifi_status=$wifiStatus  mqtt_status=$mqttStatus');
    log('   ip_address=${setResult['ip_address']}');
    log('   mac_address=${setResult['mac_address']}');

    if (wifiStatus == 'success') {
      log('✅ Wi-Fi connected!');
      step = SetupStep.success;
    } else {
      log('❌ Wi-Fi failed: wifi=$wifiStatus mqtt=$mqttStatus');
      _fail('Wi-Fi connection failed (wifi=$wifiStatus, mqtt=$mqttStatus)');
      return;
    }

    notifyListeners();
  }

  /* ─────────────────────────────────────────
     DUMMY TEST — matches client reference log
     Token: 12345000
     SSID:  "AA"       → hex 4141
     PSK:   "87654321" → hex 3837363534333231
     Extra: 0 0 0 0
     Expected result: ack ✅  then  wifi_status=failure  mqtt_status=failure
  ───────────────────────────────────────── */

  Future<void> runDummyTest() async {
    log('════════════════════════════════════════');
    log('🧪 DUMMY TEST START');
    log('════════════════════════════════════════');

    if (_device == null) {
      throw Exception('No device connected — scan first');
    }

    try {
      // Step 0: connect (if not already)
      log('🔗 Connecting…');
      await connectToDevice(_device!);

      // Step 1: /GET info
      log('📡 [DUMMY 1/4] /GET info');
      final info = await getDeviceInfo();
      log('✅ get_info: ${info['status']}  serial=${info['serial_number']}');

      // Step 2: /DISCONNECT 12345000
      log('📡 [DUMMY 2/4] /DISCONNECT 12345000');
      final disc = await disconnectFromPreviousNetwork('12345000');
      log('✅ disconnect: ${disc['status']}');

      // Step 3: /SERVER 12345000 0
      // Client reference log uses '0' as the server address for dummy test
      log('📡 [DUMMY 3/4] /SERVER 12345000 0');
      //final sResult = await setServerDummy('12345000');
    //  log('✅ server result: ${sResult["status"]}');

      // Step 4: /SET 12345000 4141 3837363534333231 0 0 0 0
      log('📡 [DUMMY 4/4] /SET dummy credentials (expect ack + failure-failure)');
    //  final setResult = await setWifiDummy('12345000');
      log('════════════════════════════════════════');
      log('🧪 DUMMY TEST RESULT:');
      // log('   wifi_status = ${setResult['wifi_status']}');
      // log('   mqtt_status = ${setResult['mqtt_status']}');
      // log('   Expected:     failure / failure');
      // final passed = setResult['wifi_status'] == 'failure' &&
      //     setResult['mqtt_status'] == 'failure';
      // log(passed ? '✅ DUMMY TEST PASSED' : '❌ DUMMY TEST FAILED');
      // log('════════════════════════════════════════');
    } catch (e) {
      log('❌ DUMMY TEST EXCEPTION: $e');
      rethrow;
    }
  }

  /* ─────────────────────────────────────────
     Fail state
  ───────────────────────────────────────── */

  void _fail(String msg) {
    log('❌ SetupController → $msg');
    step = SetupStep.error;
    status = msg;
    notifyListeners();
  }
}