// ─────────────────────────────────────────────────────────────────────────────
// features/device_connection/data/sources/ble_service.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:altum_view_sdk/core/helpers/ble_utils.dart';
import 'package:altum_view_sdk/core/networking/app_exception.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

final _sentinareV2Service = Guid('00000002-0001-11e8-8002-f4844c40006f');
final _sentinareV3Service = Guid('00000003-0001-11e8-8002-f4844c40006f');
final _rxUuid             = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
final _txUuid             = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

const _mgr = 'BLEBoard--ManagerImpl';
const _run = 'DEBUG--runner----';
const _dbg = 'DEBUG--------';

class BleService {
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;
  BluetoothDevice?         _connectedDevice;

  String?      deviceSerialNumber;
  String?      firmwareVersion;
  List<String> deviceWifiList = [];

  Completer<Map<String, dynamic>>? _pendingAck;
  Completer<Map<String, dynamic>>? _pendingResult;

  DateTime? _cmdSentAt;
  int       _cmdIndex       = 0;
  String    _currentSession = '';
  String    _responseBuffer = '';

  // ── Scan for any Sentinare device ─────────────────────────────────────────

  Future<void> startScan(void Function(BluetoothDevice) onDeviceFound) async {
    await _requestPermissions();
    await _assertBluetoothOn();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final uuids = r.advertisementData.serviceUuids;
        if (uuids.contains(_sentinareV2Service) || uuids.contains(_sentinareV3Service)) {
          bleW(_dbg, 'click connect  address ${r.device.remoteId}');
          FlutterBluePlus.stopScan();
          onDeviceFound(r.device);
          return;
        }
      }
    });
  }

  // ── Reconnect to a specific device by serial number (for calibration) ─────
  //
  // After WiFi setup completes the camera drops BLE automatically.
  // Calibration needs BLE again just for the /TOKEN command.
  // Scans until it finds the Sentinare device whose serial matches,
  // then connects and sets up notifications — same as connectToDevice().

  Future<void> connectToCalibrationDevice(String serialNumber) async {
    await _requestPermissions();
    await _assertBluetoothOn();

    log('🔍 Scanning for calibration device (serial: $serialNumber)…');

    final completer = Completer<BluetoothDevice>();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final uuids = r.advertisementData.serviceUuids;
        final isSentinare = uuids.contains(_sentinareV2Service) ||
            uuids.contains(_sentinareV3Service);
        if (isSentinare && !completer.isCompleted) {
          // Accept the first Sentinare device found.
          // If you have multiple cameras, match on name or remoteId here.
          FlutterBluePlus.stopScan();
          completer.complete(r.device);
          return;
        }
      }
    });

    final device = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        sub.cancel();
        throw const BleException('Camera not found during calibration scan');
      },
    );
    sub.cancel();

    await connectToDevice(device);
  }

  // ── Connect ────────────────────────────────────────────────────────────────

  Future<void> connectToDevice(BluetoothDevice device) async {
    bleV(_mgr, 'Connecting...');
    await device.connect(autoConnect: false, license: License.free);
    _connectedDevice = device;

    device.connectionState.listen((state) {
      final name = state == BluetoothConnectionState.connected ? 'CONNECTED' : 'DISCONNECTED';
      bleI(_mgr, name);
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final services = await device.discoverServices();
    bleI(_mgr, 'Services discovered');

    bool rxFound = false, txFound = false;

    for (final service in services) {
      for (final char in service.characteristics) {
        if (char.uuid == _txUuid) {
          _txChar = char;
          txFound = true;
          await char.setNotifyValue(true);
          bleI(_mgr, 'Notifications enabled on $_txUuid');
          // Wire incoming data — this is the listener that handles ACKs
          char.lastValueStream.listen(_onRawData);
          await char.read();
        }
        if (char.uuid == _rxUuid) {
          _rxChar = char;
          rxFound = true;
          await char.read();
        }
      }
    }

    if (!rxFound || !txFound) {
      throw BleException(
          'BLE characteristics not found (rx: $rxFound, tx: $txFound)');
    }

    final mtu = await device.requestMtu(517);
    bleI(_mgr, 'MTU: $mtu');
    bleW(_dbg, 'BLEBoard--Manager mapped state is READY');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _rxChar          = null;
    _txChar          = null;
    _connectedDevice = null;
    _responseBuffer  = '';
    log('📴 BLE disconnected');
  }

  // ── Write command ──────────────────────────────────────────────────────────

  Future<void> sendCommand(String command) async {
    if (_rxChar == null) throw const BleException('Not connected — call connectToDevice first');

    final bytes = utf8.encode('$command\n');
    _cmdSentAt  = DateTime.now();
    bleW(_run, 'command idx $_cmdIndex  sending  $command');
    _cmdIndex++;

    await _rxChar!.write(bytes, withoutResponse: false);
    bleI(_mgr, 'Data written to $_rxUuid');
  }

  // ── ACK + result (for commands that return two packets) ───────────────────

  Future<Map<String, dynamic>> sendAndWait(
      String command, {
        Duration ackTimeout    = const Duration(seconds: 15),
        Duration resultTimeout = const Duration(seconds: 10),
      }) async {
    _pendingAck    = Completer();
    _pendingResult = Completer();
    _currentSession =
    'CMD_${command.split(' ').first}_${DateTime.now().millisecondsSinceEpoch}';

    bleW(_run, 'command  starting session $_currentSession');
    await sendCommand(command);

    final ack = await _pendingAck!.future.timeout(ackTimeout,
        onTimeout: () => throw TimeoutException(
            'No ACK for "$command" within ${ackTimeout.inSeconds}s'));
    bleW(_run, 'ACK: ${ack['request_type']} status=${ack['status']}');

    final result = await _pendingResult!.future.timeout(resultTimeout,
        onTimeout: () => throw TimeoutException(
            'No result for "$command" within ${resultTimeout.inSeconds}s'));

    bleW(_run, 'command  finished session $_currentSession+++');
    return result;
  }

  // ── ACK only (for /TOKEN — camera sends NO result packet after the ACK) ───

  Future<void> sendAndWaitAck(
      String command, {
        Duration ackTimeout = const Duration(seconds: 5),
      }) async {
    _pendingAck    = Completer();
    _pendingResult = null; // explicitly null — no result expected
    _currentSession =
    'CMD_${command.split(' ').first}_${DateTime.now().millisecondsSinceEpoch}';

    bleW(_run, 'command (ack-only)  starting session $_currentSession');
    await sendCommand(command);

    final ack = await _pendingAck!.future.timeout(ackTimeout,
        onTimeout: () => throw TimeoutException(
            'No ACK for "$command" within ${ackTimeout.inSeconds}s.\n'
                'Camera may have dropped BLE after WiFi setup. '
                'Check that connectToCalibrationDevice() was called first.'));

    bleW(_run, 'ACK (ack-only): ${ack['request_type']} status=${ack['status']}');
    bleW(_run, 'command (ack-only)  finished session $_currentSession+++');
  }

  // ── Incoming data ──────────────────────────────────────────────────────────

  void _onRawData(List<int> data) {
    if (data.isEmpty) return;

    bleI(_mgr, 'Notification received from $_txUuid, value: (0x) ${bytesToHex(data)}');

    _responseBuffer += String.fromCharCodes(data);

    while (true) {
      final start = _responseBuffer.indexOf('{');
      if (start == -1) { _responseBuffer = ''; break; }

      int  braceCount = 0;
      bool inString   = false;
      int  end        = -1;

      for (int i = start; i < _responseBuffer.length; i++) {
        final ch   = _responseBuffer[i];
        final prev = i > 0 ? _responseBuffer[i - 1] : '';
        if (ch == '"' && prev != '\\') { inString = !inString; continue; }
        if (!inString) {
          if (ch == '{') braceCount++;
          if (ch == '}') { braceCount--; if (braceCount == 0) { end = i; break; } }
        }
      }

      if (end == -1) break;

      final jsonStr = _responseBuffer.substring(start, end + 1);
      int consume   = end + 1;
      while (consume < _responseBuffer.length &&
          ';\n\r '.contains(_responseBuffer[consume])) consume++;
      _responseBuffer = _responseBuffer.substring(consume);

      _processJson(jsonStr);
    }
  }

  void _processJson(String raw) {
    final cleaned = raw
        .replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ')
        .replaceAllMapped(RegExp(r',\s*([\]}])'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'\s+'), ' ').trim();

    Map<String, dynamic> json;
    try {
      json = jsonDecode(cleaned);
    } catch (e) {
      bleW(_mgr, 'JSON parse failed: $e');
      return;
    }

    final requestType = json['request_type'] as String? ?? '';
    final status      = json['status']       as String? ?? '';

    // ── ACK ─────────────────────────────────────────────────────────────────
    if (status == 'ack') {
      final ms = _cmdSentAt != null
          ? DateTime.now().difference(_cmdSentAt!).inMilliseconds / 1000.0 : 0.0;
      bleW(_run, 'ACK received  trip ${ms.toStringAsFixed(3)}');
      _pendingAck?.complete(json);
      _pendingAck = null;
      return; // if _pendingResult is null (ack-only), we are done
    }

    // ── Device info ─────────────────────────────────────────────────────────
    if (requestType == 'get_info' && json['serial_number'] != null) {
      deviceSerialNumber = json['serial_number'] as String;
      firmwareVersion    = json['firmware_version'] as String?;
    }

    // ── WiFi list ───────────────────────────────────────────────────────────
    if (requestType == 'get_network_list' && json['result'] is List) {
      deviceWifiList.clear();
      for (final item in json['result'] as List) {
        if (item['name'] is String) deviceWifiList.add(hexToString(item['name'] as String));
      }
    }

    // ── Result ──────────────────────────────────────────────────────────────
    final ms = _cmdSentAt != null
        ? DateTime.now().difference(_cmdSentAt!).inMilliseconds / 1000.0 : 0.0;
    bleW(_run, 'result ok ++++  session: $_currentSession  trip ${ms.toStringAsFixed(3)}');

    _pendingResult?.complete(json);
    _pendingResult = null;
  }

  // ── Named BLE commands ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDeviceInfo() =>
      sendAndWait('/GET info',
          ackTimeout: const Duration(seconds: 5),
          resultTimeout: const Duration(seconds: 10));

  Future<Map<String, dynamic>> getWifiList() =>
      sendAndWait('/GET network_list',
          ackTimeout: const Duration(seconds: 5),
          resultTimeout: const Duration(seconds: 30));

  Future<Map<String, dynamic>> disconnectFromPreviousNetwork(String token) =>
      sendAndWait('/DISCONNECT $token',
          ackTimeout: const Duration(seconds: 5),
          resultTimeout: const Duration(seconds: 10));

  Future<Map<String, dynamic>> setServer(String token) =>
      sendAndWait('/SERVER $token prodca.altumview.ca',
          ackTimeout: const Duration(seconds: 5),
          resultTimeout: const Duration(seconds: 15));

  Future<Map<String, dynamic>> setWifi({
    required String token,
    required String ssid,
    required String password,
    required String mqttPasscode,
    required String groupId,
  }) {
    final cmd =
    '/SET $token ${toHex(ssid)} ${toHex(password)} $mqttPasscode pool.ntp.org '
        'https://cert.altumview.com/Altumview_Trust_x509.pem $groupId'
        .replaceAll(RegExp(r'\s+'), ' ').trim();
    log('📡 /SET command: $cmd');
    return sendAndWait(cmd,
        ackTimeout: const Duration(seconds: 15),
        resultTimeout: const Duration(seconds: 90));
  }

  Future<Map<String, dynamic>> factoryReset(String token) =>
      sendAndWait('/FACTORY_RESET $token',
          ackTimeout: const Duration(seconds: 5),
          resultTimeout: const Duration(seconds: 15));

  // /TOKEN sends ACK only — never a result packet
  Future<void> enableCalibrationPreview(String token) async {
    await sendAndWaitAck('/TOKEN previewToken $token',
        ackTimeout: const Duration(seconds: 5));
    log('✅ Preview token set: $token');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    final scan    = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (!scan.isGranted || !connect.isGranted) {
      throw const BleException('Bluetooth permissions not granted');
    }
    if (await Permission.location.isDenied) await Permission.location.request();
  }

  Future<void> _assertBluetoothOn() async {
    if (!await FlutterBluePlus.isOn) throw const BleException('Bluetooth is turned off');
  }
}