// ─────────────────────────────────────────────────────────────────────────────
// features/device_connection/data/sources/ble_service.dart
//
// All raw Bluetooth Low Energy (BLE) logic.
// Extracted 1-for-1 from altum_view_controller.dart — NO logic changes.
//
// Responsibilities:
//   • Scan for Sentinare BLE cameras
//   • Connect, negotiate MTU, enable notifications
//   • Send commands and wait for ACK + result
//   • Parse incoming JSON notifications
//   • Log in the exact format the camera vendor expects
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:altum_view_sdk/core/helpers/ble_utils.dart';
import 'package:altum_view_sdk/core/networking/app_exception.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// ── BLE UUIDs ─────────────────────────────────────────────────────────────────

final _sentinareV2Service = Guid('00000002-0001-11e8-8002-f4844c40006f');
final _sentinareV3Service = Guid('00000003-0001-11e8-8002-f4844c40006f');
final _rxUuid             = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e'); // write
final _txUuid             = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e'); // notify

// ── Tag constants matching vendor log format ──────────────────────────────────

const _mgr = 'BLEBoard--ManagerImpl';
const _run = 'DEBUG--runner----';
const _dbg = 'DEBUG--------';

class BleService {
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;

  // Device info populated after /GET info
  String? deviceSerialNumber;
  String? firmwareVersion;
  List<String> deviceWifiList = [];

  // Response completers
  Completer<Map<String, dynamic>>? _pendingAck;
  Completer<Map<String, dynamic>>? _pendingResult;

  // Logging helpers
  DateTime? _cmdSentAt;
  int       _cmdIndex      = 0;
  String    _currentSession = '';
  String    _responseBuffer = '';

  // ── Scan ───────────────────────────────────────────────────────────────────

  /// Requests permissions, starts a 10-second BLE scan and calls
  /// [onDeviceFound] with the first matching Sentinare device.
  Future<void> startScan(
      void Function(BluetoothDevice device) onDeviceFound,
      ) async {
    final scanStatus    = await Permission.bluetoothScan.request();
    final connectStatus = await Permission.bluetoothConnect.request();

    if (!scanStatus.isGranted || !connectStatus.isGranted) {
      bleW(_dbg, 'Bluetooth permission denied');
      throw const BleException('Bluetooth permissions not granted');
    }

    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }

    final isOn = await FlutterBluePlus.isOn;
    if (!isOn) {
      bleW(_dbg, 'Bluetooth is OFF');
      throw const BleException('Bluetooth is turned off');
    }

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          final uuids = r.advertisementData.serviceUuids;
          if (uuids.contains(_sentinareV2Service) ||
              uuids.contains(_sentinareV3Service)) {
            bleW(_dbg, 'click connect  address ${r.device.remoteId}');
            FlutterBluePlus.stopScan();
            onDeviceFound(r.device);
            return;
          }
        }
      });
    } catch (e) {
      bleW(_dbg, 'BLE scan error: $e');
      rethrow;
    }
  }

  // ── Connect ────────────────────────────────────────────────────────────────

  /// Connects, discovers services, enables notifications, requests MTU 517.
  /// Sequence mirrors the vendor's Android reference log exactly.
  Future<void> connectToDevice(BluetoothDevice device) async {
    bleV(_mgr, 'Connecting...');
    bleD(_mgr, 'gatt = device.connectGatt(autoConnect = false, TRANSPORT_LE, LE 1M)');

    await device.connect(autoConnect: false, license: License.free);

    device.connectionState.listen((state) {
      final code = state == BluetoothConnectionState.connected ? 2 : 0;
      final name = state == BluetoothConnectionState.connected
          ? 'CONNECTED'
          : 'DISCONNECTED';
      bleD(_mgr,
          '[Callback] Connection state changed with status: 0 and new state: $code ($name)');
      bleI(_mgr,
          state == BluetoothConnectionState.connected
              ? 'Connected to ${device.remoteId}'
              : 'Disconnected');
    });

    bleD(_mgr, 'wait(300)');
    await Future.delayed(const Duration(milliseconds: 300));

    bleV(_mgr, 'Discovering services...');
    bleD(_mgr, 'gatt.discoverServices()');
    final services = await device.discoverServices();
    bleI(_mgr, 'Services discovered');
    bleV(_mgr, 'Primary service found');

    bool rxFound = false, txFound = false;

    for (final service in services) {
      for (final char in service.characteristics) {
        if (char.uuid == _txUuid) {
          _txChar = char;
          txFound = true;
          bleD(_mgr, 'gatt.setCharacteristicNotification($_txUuid, true)');
          bleV(_mgr, 'Enabling notifications for $_txUuid');
          bleD(_mgr, 'descriptor.setValue(0x01-00)');
          bleD(_mgr,
              'gatt.writeDescriptor(6e400003-b5a3-f393-e0a9-e50e24dcca9e)');
          await char.setNotifyValue(true);
          bleI(_mgr,
              'Data written to descr. 6e400003-b5a3-f393-e0a9-e50e24dcca9e');
          bleI(_mgr, 'Notifications enabled');

          char.lastValueStream.listen(_onRawData);

          bleV(_mgr, 'Reading characteristic $_txUuid');
          bleD(_mgr, 'gatt.readCharacteristic($_txUuid)');
          final txVal = await char.read();
          bleI(_mgr,
              'Read Response received from $_txUuid, value: '
                  '${txVal.isEmpty ? "(empty)" : bytesToHex(txVal)}');
        }

        if (char.uuid == _rxUuid) {
          _rxChar = char;
          rxFound = true;
          bleV(_mgr, 'Reading characteristic $_rxUuid');
          bleD(_mgr, 'gatt.readCharacteristic($_rxUuid)');
          final rxVal = await char.read();
          bleI(_mgr,
              'Read Response received from $_rxUuid, value: '
                  '${rxVal.isEmpty ? "(empty)" : bytesToHex(rxVal)}');
        }
      }
    }

    if (!rxFound || !txFound) {
      throw BleException(
          'Required BLE characteristics not found (rx: $rxFound, tx: $txFound)');
    }

    bleV(_mgr, 'Requesting new MTU...');
    bleD(_mgr, 'gatt.requestMtu(517)');
    final mtu = await device.requestMtu(517);
    bleI(_mgr, 'MTU changed to: $mtu');
    bleW(_dbg, 'BLEBoard--Manager mapped state is READY');

    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ── Send command ───────────────────────────────────────────────────────────

  Future<void> sendCommand(String command) async {
    if (_rxChar == null) throw const BleException('Not connected — call connectToDevice first');

    final payload = '$command\n';
    final bytes   = utf8.encode(payload);
    final hexVal  =
        '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

    _cmdSentAt = DateTime.now();
    bleW(_run, 'command idx $_cmdIndex  sending  $command');
    _cmdIndex++;

    bleV(_mgr, 'Writing characteristic $_rxUuid (WRITE REQUEST)');
    bleD(_mgr, 'characteristic.setValue($hexVal)');
    bleD(_mgr, 'characteristic.setWriteType(WRITE REQUEST)');
    bleD(_mgr, 'gatt.writeCharacteristic($_rxUuid)');

    await _rxChar!.write(bytes, withoutResponse: false);
    bleI(_mgr, 'Data written to $_rxUuid');
  }

  // ── Send + wait for ACK + result ───────────────────────────────────────────

  Future<Map<String, dynamic>> sendAndWait(
      String command, {
        Duration ackTimeout    = const Duration(seconds: 15),
        Duration resultTimeout = const Duration(seconds: 10),
      }) async {
    _pendingAck    = Completer<Map<String, dynamic>>();
    _pendingResult = Completer<Map<String, dynamic>>();
    _currentSession =
    'CMD_${command.split(' ').first}_${DateTime.now().millisecondsSinceEpoch}';

    bleW(_run, 'command  starting session $_currentSession');
    await sendCommand(command);

    final ack = await _pendingAck!.future.timeout(
      ackTimeout,
      onTimeout: () => throw TimeoutException(
          'No ACK for "$command" within ${ackTimeout.inSeconds}s'),
    );
    bleW(_run, 'ACK confirmed: ${ack['request_type']} status=${ack['status']}');

    final result = await _pendingResult!.future.timeout(
      resultTimeout,
      onTimeout: () => throw TimeoutException(
          'No result for "$command" within ${resultTimeout.inSeconds}s'),
    );

    bleW(_run, 'command  finished session $_currentSession+++');
    return result;
  }

  // ── Incoming data handler ──────────────────────────────────────────────────

  void _onRawData(List<int> data) {
    if (data.isEmpty) return;

    final hex   = bytesToHex(data);
    final ascii = String.fromCharCodes(data);

    bleI(_mgr, 'Notification received from $_txUuid, value: (0x) $hex');

    for (final line in ascii.split('\n')) {
      if (line.trim().isNotEmpty) {
        bleI('BLEBoard--Repository\$decoded', line);
      }
    }

    _responseBuffer += ascii;

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

      final jsonString = _responseBuffer.substring(start, end + 1);
      int consume = end + 1;
      while (consume < _responseBuffer.length &&
          ';,\n\r '.contains(_responseBuffer[consume])) consume++;
      _responseBuffer = _responseBuffer.substring(consume);

      _processJson(jsonString);
    }
  }

  void _processJson(String raw) {
    final cleaned = raw
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAllMapped(RegExp(r',\s*([\]}])'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    Map<String, dynamic> json;
    try {
      json = jsonDecode(cleaned);
    } catch (e) {
      bleW(_mgr, 'JSON parse failed: $e  raw=${cleaned.length}chars');
      return;
    }

    final requestType = json['request_type'] as String? ?? '';
    final status      = json['status']       as String? ?? '';

    if (status == 'ack') {
      final tripMs = _cmdSentAt != null
          ? DateTime.now().difference(_cmdSentAt!).inMilliseconds / 1000.0
          : 0.0;
      bleW(_run, 'command  received ACK for $_currentSession');
      bleW(_run, 'result timing ++++  trip ${tripMs.toStringAsFixed(3)}');
      _pendingAck?.complete(json);
      _pendingAck = null;
      return;
    }

    if (requestType == 'get_info' && json['serial_number'] != null) {
      deviceSerialNumber = json['serial_number'] as String;
      firmwareVersion    = json['firmware_version'] as String?;
    }

    if (requestType == 'get_network_list' && json['result'] is List) {
      deviceWifiList.clear();
      for (final item in json['result'] as List) {
        if (item['name'] is String) {
          deviceWifiList.add(hexToString(item['name'] as String));
        }
      }
    }

    final tripMs = _cmdSentAt != null
        ? DateTime.now().difference(_cmdSentAt!).inMilliseconds / 1000.0
        : 0.0;
    bleW(_run, 'result ok ++++');
    bleW(_run, 'result line ++++  Command-session: $_currentSession');
    bleW(_run, 'result timing ++++  trip ${tripMs.toStringAsFixed(3)}');

    _pendingResult?.complete(json);
    _pendingResult = null;
  }

  // ── Public BLE commands ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDeviceInfo() => sendAndWait(
    '/GET info',
    ackTimeout:    const Duration(seconds: 5),
    resultTimeout: const Duration(seconds: 10),
  );

  Future<Map<String, dynamic>> getWifiList() => sendAndWait(
    '/GET network_list',
    ackTimeout:    const Duration(seconds: 5),
    resultTimeout: const Duration(seconds: 30),
  );

  Future<Map<String, dynamic>> disconnectFromPreviousNetwork(String token) =>
      sendAndWait(
        '/DISCONNECT $token',
        ackTimeout:    const Duration(seconds: 5),
        resultTimeout: const Duration(seconds: 10),
      );

  Future<Map<String, dynamic>> setServer(String token) => sendAndWait(
    '/SERVER $token prodca.altumview.ca',
    ackTimeout:    const Duration(seconds: 5),
    resultTimeout: const Duration(seconds: 15),
  );

  Future<Map<String, dynamic>> setWifi({
    required String token,
    required String ssid,
    required String password,
    required String mqttPasscode,
    required String groupId,
  })
  {
    final encodedSsid = toHex(ssid);
    final encodedPsk  = toHex(password);
    const ntp  = 'pool.ntp.org';
    const cert = 'https://cert.altumview.com/Altumview_Trust_x509.pem';
    var command =
        '/SET $token $encodedSsid $encodedPsk $mqttPasscode $ntp $cert $groupId';
    command = command.replaceAll(RegExp(r'\s+'), ' ').trim();
    log('📡 /SET command: $command');

    return sendAndWait(
      command,
      ackTimeout:    const Duration(seconds: 15),
      resultTimeout: const Duration(seconds: 90),
    );
  }

  Future<Map<String, dynamic>> factoryReset(String token) => sendAndWait(
    '/FACTORY_RESET $token',
    ackTimeout:    const Duration(seconds: 5),
    resultTimeout: const Duration(seconds: 15),
  );

  Future<void> enableCalibrationPreview(String token) async {
    await sendAndWait(
      '/TOKEN previewToken $token',
      ackTimeout:    const Duration(seconds: 5),
      resultTimeout: const Duration(seconds: 10),
    );
    log('✅ Preview token set: $token');
  }
}