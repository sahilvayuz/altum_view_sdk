import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io' show Platform;
import 'dart:typed_data' show ByteData, Uint8List, Endian;
import 'package:altum_view_sdk/features/altum_view/data/room_model.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:permission_handler/permission_handler.dart';

String authToken =
    '289201-e55902b0ffdcd734d4e6dd6c58cd3ba9353602ea962afb7b1d7557855b425efc';

String mqttPass='';
int? cameraId;

/* ═══════════════════════════════════════════════════════════
   STRUCTURED BLE LOG
   Produces output in the exact format the camera vendor
   expects, mirroring their Android reference log:
     MM-DD HH:MM:SS.mmm  LEVEL  TAG: Message
   ═══════════════════════════════════════════════════════════ */

final List<String> bleLog = [];

// Mirrors Android logcat timestamp format: MM-DD HH:MM:SS.mmm
String _ts() {
  final n = DateTime.now();
  final mo = n.month.toString().padLeft(2, '0');
  final d  = n.day.toString().padLeft(2, '0');
  final h  = n.hour.toString().padLeft(2, '0');
  final mi = n.minute.toString().padLeft(2, '0');
  final s  = n.second.toString().padLeft(2, '0');
  final ms = n.millisecond.toString().padLeft(3, '0');
  return '$mo-$d $h:$mi:$s.$ms';
}

void _ble(String level, String tag, String msg) {
  final line = '${_ts()} $level $tag: $msg';
  log(line);
  bleLog.add(line);
}

// Convenience shorthands matching client log levels
void _bleV(String tag, String msg) => _ble('V', tag, msg);
void _bleD(String tag, String msg) => _ble('D', tag, msg);
void _bleI(String tag, String msg) => _ble('I', tag, msg);
void _bleW(String tag, String msg) => _ble('W', tag, msg);

const _mgr  = 'BLEBoard--ManagerImpl';
const _run  = 'DEBUG--runner----';
const _dbg  = 'DEBUG--------';

/* ───────── HEX HELPERS ───────── */

String _bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join('-');

String toHex(String input) =>
    input.codeUnits.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

String _hexToString(String hex) {
  final bytes = <int>[];
  for (int i = 0; i + 1 < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return String.fromCharCodes(bytes);
}

/* ───────── BLE UUIDs ───────── */

final sentinareV2Service = Guid('00000002-0001-11e8-8002-f4844c40006f');
final sentinareV3Service = Guid('00000003-0001-11e8-8002-f4844c40006f');

final rxUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e'); // write
final txUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e'); // notify

late BluetoothCharacteristic rxChar;
late BluetoothCharacteristic txChar;

/* ───────── DEVICE STATE ───────── */

String? deviceSerialNumber;
String? firmwareVersion;
List<String> deviceWifiList = [];

/* ───────── RESPONSE COMPLETERS ───────── */

Completer<Map<String, dynamic>>? _pendingAck;
Completer<Map<String, dynamic>>? _pendingResult;

/* ───────── COMMAND TIMING ───────── */

DateTime? _cmdSentAt;
int _cmdIndex = 0;
String _currentSession = '';

/* ═══════════════════════════════════════════════════════════
   STEP 1 — Scan
   ═══════════════════════════════════════════════════════════ */

Future<void> startScan(
    void Function(BluetoothDevice device) onDeviceFound,
    )
async {
  final scanStatus    = await Permission.bluetoothScan.request();
  final connectStatus = await Permission.bluetoothConnect.request();

  if (!scanStatus.isGranted || !connectStatus.isGranted) {
    _bleW(_dbg, 'Bluetooth permission denied');
    return;
  }
  if (await Permission.location.isDenied) await Permission.location.request();

  final isOn = await FlutterBluePlus.isOn;
  if (!isOn) { _bleW(_dbg, 'Bluetooth is OFF'); return; }

  try {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final uuids = r.advertisementData.serviceUuids;
        if (uuids.contains(sentinareV2Service) || uuids.contains(sentinareV3Service)) {
          _bleW(_dbg, 'click connect  address ${r.device.remoteId}');
          FlutterBluePlus.stopScan();
          onDeviceFound(r.device);
          return;
        }
      }
    });
  } catch (e) {
    _bleW(_dbg, 'BLE scan error: $e');
  }
}

/* ═══════════════════════════════════════════════════════════
   STEP 2 — Connect + MTU + Notifications
   Exact sequence from client reference log:
     connectGatt → wait(300) → discoverServices →
     setCharacteristicNotification(tx, true) →
     descriptor.setValue(0x01-00) → writeDescriptor →
     readCharacteristic(tx) → readCharacteristic(rx) →
     requestMtu(517)
   ═══════════════════════════════════════════════════════════ */

Future<void> connectToDevice(BluetoothDevice device) async {
  // ── 1. Initiate connection ────────────────────────────────
  _bleV(_mgr, 'Connecting...');
  _bleD(_mgr, 'gatt = device.connectGatt(autoConnect = false, TRANSPORT_LE, LE 1M)');

  await device.connect(autoConnect: false, license: License.free,);

  // ── 2. State change callback ─────────────────────────────
  device.connectionState.listen((state) {
    final stateCode = state == BluetoothConnectionState.connected ? 2 : 0;
    final stateName = state == BluetoothConnectionState.connected
        ? 'CONNECTED' : 'DISCONNECTED';
    _bleD(_mgr, '[Callback] Connection state changed with status: 0 '
        'and new state: $stateCode ($stateName)');
    if (state == BluetoothConnectionState.connected) {
      _bleI(_mgr, 'Connected to ${device.remoteId}');
    } else {
      _bleI(_mgr, 'Disconnected');
    }
  });

  // ── 3. Settle delay (matches client: wait(300)) ──────────
  _bleD(_mgr, 'wait(300)');
  await Future.delayed(const Duration(milliseconds: 300));

  // ── 4. Discover services ─────────────────────────────────
  _bleV(_mgr, 'Discovering services...');
  _bleD(_mgr, 'gatt.discoverServices()');
  final services = await device.discoverServices();
  _bleI(_mgr, 'Services discovered');
  _bleV(_mgr, 'Primary service found');

  bool rxFound = false, txFound = false;

  for (final service in services) {
    for (final char in service.characteristics) {

      if (char.uuid == txUuid) {
        txChar = char;
        txFound = true;

        // ── 5. Enable notifications ─────────────────────────
        _bleD(_mgr, 'gatt.setCharacteristicNotification($txUuid, true)');
        _bleV(_mgr, 'Enabling notifications for $txUuid');
        _bleD(_mgr, 'descriptor.setValue(0x01-00)');
        _bleD(_mgr, 'gatt.writeDescriptor(6e400003-b5a3-f393-e0a9-e50e24dcca9e)');
        await txChar.setNotifyValue(true);
        _bleI(_mgr, 'Data written to descr. 6e400003-b5a3-f393-e0a9-e50e24dcca9e');
        _bleI(_mgr, 'Notifications enabled');

        // ── 6. Subscribe to incoming data ───────────────────
        txChar.lastValueStream.listen(_onRawData);

        // ── 7. Initial read of TX char ───────────────────────
        _bleV(_mgr, 'Reading characteristic $txUuid');
        _bleD(_mgr, 'gatt.readCharacteristic($txUuid)');
        final txVal = await txChar.read();
        _bleI(_mgr, 'Read Response received from $txUuid, value: '
            '${txVal.isEmpty ? "(empty)" : _bytesToHex(txVal)}');
      }

      if (char.uuid == rxUuid) {
        rxChar = char;
        rxFound = true;

        // ── 8. Initial read of RX char ───────────────────────
        _bleV(_mgr, 'Reading characteristic $rxUuid');
        _bleD(_mgr, 'gatt.readCharacteristic($rxUuid)');
        final rxVal = await rxChar.read();
        _bleI(_mgr, 'Read Response received from $rxUuid, value: '
            '${rxVal.isEmpty ? "(empty)" : _bytesToHex(rxVal)}');
      }
    }
  }

  if (!rxFound || !txFound) {
    throw Exception(
        'Required BLE characteristics not found (rx: $rxFound, tx: $txFound)');
  }

  // ── 9. Request MTU 517 ────────────────────────────────────
  _bleV(_mgr, 'Requesting new MTU...');
  _bleD(_mgr, 'gatt.requestMtu(517)');
  final mtu = await device.requestMtu(517);
  _bleI(_mgr, 'MTU changed to: $mtu');
  _bleW(_dbg, 'BLEBoard--Manager mapped state is READY');

  await Future.delayed(const Duration(milliseconds: 500));
}

/* ═══════════════════════════════════════════════════════════
   STEP 3 — Incoming notification handler
   Logs raw hex exactly as client format:
     Notification received from <uuid>, value: (0x) HH-HH-HH...
   Then logs decoded JSON line by line.
   ═══════════════════════════════════════════════════════════ */

String _responseBuffer = '';

void _onRawData(List<int> data) {
  if (data.isEmpty) return;

  final hex   = _bytesToHex(data);
  final ascii = String.fromCharCodes(data);

  // Raw stream — matches client format exactly
  _bleI(_mgr, 'Notification received from $txUuid, value: (0x) $hex');

  // Decoded line-by-line (matches client "Button pressed or released:" style)
  for (final line in ascii.split('\n')) {
    if (line.trim().isNotEmpty) {
      _bleI('BLEBoard--Repository\$decoded', line);
    }
  }

  _responseBuffer += ascii;

  while (true) {
    final start = _responseBuffer.indexOf('{');
    if (start == -1) { _responseBuffer = ''; break; }

    int braceCount = 0;
    bool inString  = false;
    int end        = -1;

    for (int i = start; i < _responseBuffer.length; i++) {
      final ch   = _responseBuffer[i];
      final prev = i > 0 ? _responseBuffer[i - 1] : '';
      if (ch == '"' && prev != '\\') { inString = !inString; continue; }
      if (!inString) {
        if (ch == '{') braceCount++;
        if (ch == '}') { braceCount--; if (braceCount == 0) { end = i; break; } }
      }
    }

    if (end == -1) break; // incomplete — keep buffering

    final jsonString = _responseBuffer.substring(start, end + 1);

    // Consume trailing "; \n"
    int consume = end + 1;
    while (consume < _responseBuffer.length &&
        ';,\n\r '.contains(_responseBuffer[consume])) consume++;
    _responseBuffer = _responseBuffer.substring(consume);

    _processJson(jsonString);
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
    _bleW(_mgr, 'JSON parse failed: $e  raw=${cleaned.length}chars');
    return;
  }

  final requestType = json['request_type'] as String? ?? '';
  final status      = json['status']       as String? ?? '';

  // ── ACK ──────────────────────────────────────────────────
  if (status == 'ack') {
    final tripMs = _cmdSentAt != null
        ? DateTime.now().difference(_cmdSentAt!).inMilliseconds / 1000.0
        : 0.0;
    _bleW(_run, 'command  received ACK for $_currentSession');
    _bleW(_run, 'result timing ++++  trip ${tripMs.toStringAsFixed(3)}');
    _pendingAck?.complete(json);
    _pendingAck = null;
    return;
  }

  // ── Final results ─────────────────────────────────────────
  if (requestType == 'get_info' && json['serial_number'] != null) {
    deviceSerialNumber = json['serial_number'] as String;
    firmwareVersion    = json['firmware_version'] as String?;
  }

  if (requestType == 'get_network_list' && json['result'] is List) {
    deviceWifiList.clear();
    for (final item in json['result'] as List) {
      if (item['name'] is String) {
        deviceWifiList.add(_hexToString(item['name'] as String));
      }
    }
  }

  // Log final result in client style
  final tripMs = _cmdSentAt != null
      ? DateTime.now().difference(_cmdSentAt!).inMilliseconds / 1000.0
      : 0.0;
  _bleW(_run, 'result ok ++++');
  _bleW(_run, 'result line ++++  Command-session: $_currentSession');
  _bleW(_run, 'result timing ++++  trip ${tripMs.toStringAsFixed(3)}');

  _pendingResult?.complete(json);
  _pendingResult = null;
}

/* ═══════════════════════════════════════════════════════════
   STEP 4 — Send command
   Logs in client format:
     Writing characteristic <uuid> (WRITE REQUEST)
     characteristic.setValue(0x<hex>)
     characteristic.setWriteType(WRITE REQUEST)
     gatt.writeCharacteristic(<uuid>)
     Data written to <uuid>
   ═══════════════════════════════════════════════════════════ */

Future<void> sendCommand(String command) async {
  final payload = '$command\n';
  final bytes   = utf8.encode(payload);
  final hexVal  = '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

  _cmdSentAt = DateTime.now();

  _bleW(_run, 'command idx $_cmdIndex  sending  $command');
  _cmdIndex++;

  _bleV(_mgr, 'Writing characteristic $rxUuid (WRITE REQUEST)');
  _bleD(_mgr, 'characteristic.setValue($hexVal)');
  _bleD(_mgr, 'characteristic.setWriteType(WRITE REQUEST)');
  _bleD(_mgr, 'gatt.writeCharacteristic($rxUuid)');

  await rxChar.write(bytes, withoutResponse: false);

  _bleI(_mgr, 'Data written to $rxUuid');
}

/* ═══════════════════════════════════════════════════════════
   STEP 5 — Send + wait for ACK + result
   ═══════════════════════════════════════════════════════════ */

Future<Map<String, dynamic>> _sendAndWait(
    String command, {
      Duration ackTimeout    = const Duration(seconds: 15),
      Duration resultTimeout = const Duration(seconds: 10),
    }) async {
  _pendingAck    = Completer<Map<String, dynamic>>();
  _pendingResult = Completer<Map<String, dynamic>>();
  _currentSession = 'CMD_${command.split(' ').first}_${DateTime.now().millisecondsSinceEpoch}';

  _bleW(_run, 'command  starting session $_currentSession');

  await sendCommand(command);

  final ack = await _pendingAck!.future.timeout(
    ackTimeout,
    onTimeout: () => throw TimeoutException(
        'No ACK for "$command" within ${ackTimeout.inSeconds}s'),
  );
  _bleW(_run, 'ACK confirmed: ${ack['request_type']} status=${ack['status']}');

  final result = await _pendingResult!.future.timeout(
    resultTimeout,
    onTimeout: () => throw TimeoutException(
        'No result for "$command" within ${resultTimeout.inSeconds}s'),
  );

  _bleW(_run, 'command  finished session $_currentSession+++');
  return result;
}

/* ═══════════════════════════════════════════════════════════
   Public command APIs
   ═══════════════════════════════════════════════════════════ */

Future<Map<String, dynamic>> getDeviceInfo() => _sendAndWait(
  '/GET info',
  ackTimeout:    const Duration(seconds: 5),
  resultTimeout: const Duration(seconds: 10),
);

Future<Map<String, dynamic>> getWifiList() => _sendAndWait(
  '/GET network_list',
  ackTimeout:    const Duration(seconds: 5),
  resultTimeout: const Duration(seconds: 30),
);

Future<Map<String, dynamic>> disconnectFromPreviousNetwork(String token) =>
    _sendAndWait(
      '/DISCONNECT $token',
      ackTimeout:    const Duration(seconds: 5),
      resultTimeout: const Duration(seconds: 10),
    );

Future<Map<String, dynamic>> setServer(String token) => _sendAndWait(
  '/SERVER $token prodca.altumview.ca',
  ackTimeout:    const Duration(seconds: 5),
  resultTimeout: const Duration(seconds: 15),
);

/// Dummy server — matches client reference log exactly: /SERVER 12345000 0
Future<Map<String, dynamic>> setServerDummy(String token) => _sendAndWait(
  '/SERVER $token 0',
  ackTimeout:    const Duration(seconds: 5),
  resultTimeout: const Duration(seconds: 15),
);

/// Dummy /SET — exact replica of client reference log command
/// /SET 12345000 4141 3837363534333231 0 0 0 0
/// Expected response: ack immediately, then wifi_status=failure mqtt_status=failure (~58s)
Future<Map<String, dynamic>> setWifiDummy(String token) {
  const command = '/SET 12345000 4141 3837363534333231 0 0 0 0';
  _bleW(_run, '[DUMMY TEST] Sending: $command');
  return _sendAndWait(
    command,
    ackTimeout:    const Duration(seconds: 15),
    resultTimeout: const Duration(seconds: 90),
  );
}

/// Production /SET
/// 7 positional params — position-for-position replacement of the 4 dummy zeros:
///   pos4=ntp  pos5=cert  pos6=port(4528)  pos7=group_id
Future<Map<String, dynamic>> setWifi({
  required String token,
  required String ssid,
  required String password,
  required String groupId,
})
async{
  final encodedSsid = toHex(ssid);
  final encodedPsk  = toHex(password);

  const ntp  = 'pool.ntp.org';
  const cert = 'https://cert.altumview.com/Altumview_Trust_x509.pem';

  final ntpHex= toHex(ntp.trim());
  final certHex= toHex(cert.toString());
  final String mqttPassHex= toHex(mqttPass.trim());
  final groupIdHex= toHex(groupId.trim());

  // Add this call before setWifi
  final infoResp = await http.get(
    Uri.parse('https://api.altumview.ca/v1.0/info'),
    headers: {'Authorization': 'Bearer $authToken'},
  );
  log('INFO response: ${infoResp.body}');

  var command =
      '/SET $token $encodedSsid $encodedPsk $mqttPass $ntp $cert $groupId';

// Remove multiple spaces → single space
  command = command.replaceAll(RegExp(r'\s+'), ' ').trim();
  log('this is the set command: $command');
//  /SET 644777465 564159555a205370656374726120 566179757a4032303236 QxltNOOY3O6UujvlyXafaVi4iBecRTxS "" "" 4528

  //   final command =
  //       '/SET 713975493 564159555a205370656374726120 566179757a4032303236 gttSPdjRI4H6lUyhYAlyMOqXBJ0duS1T "" "" 4528';

  _bleW(_run, '[PROD /SET] token=$token ssid_hex=$encodedSsid psk_hex=$encodedPsk');

  return _sendAndWait(
    command,
    ackTimeout:    const Duration(seconds: 15),
    resultTimeout: const Duration(seconds: 90),
  );
}

/* ═══════════════════════════════════════════════════════════
   Cloud APIs
   ═══════════════════════════════════════════════════════════ */

Future<String> getBluetoothToken(String serial) async {
  final response = await http.get(
    Uri.parse('https://api.altumview.ca/v1.0/cameras/bluetoothToken?serial_number=$serial'),
    headers: {'Authorization': 'Bearer $authToken'},
  );
  final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  if (json['success'] != true) throw Exception(json['message'] ?? 'Token request failed');
  final data = json['data'] as Map<String, dynamic>;

  final cameraExist = data['camera_exist'] == true;
  if (cameraExist) {
    log('⚠️ Camera already exists — deleting before fresh registration');
    await deleteCamera(serial: serial, accessToken: authToken);

    // ✅ Fetch a FRESH token after deletion
    final freshResp = await http.get(
      Uri.parse('https://api.altumview.ca/v1.0/cameras/bluetoothToken?serial_number=$serial'),
      headers: {'Authorization': 'Bearer $authToken'},
    );
    final freshJson = jsonDecode(utf8.decode(freshResp.bodyBytes)) as Map<String, dynamic>;
    if (freshJson['success'] != true) throw Exception(freshJson['message'] ?? 'Fresh token request failed');
    final freshToken = freshJson['data']['bluetooth_token'];
    if (freshToken == null) throw Exception('bluetooth_token missing in fresh response');
    log('✅ Fresh bluetooth token after delete: $freshToken');
    return freshToken.toString();
  }

  final token = data['bluetooth_token'];
  if (token == null) throw Exception('bluetooth_token missing in response');
  return token.toString();
}


Future<void> deleteCamera({
  required String serial,
  required String accessToken,
})
async {
  // First get the camera id by serial
  final listResp = await http.get(
    Uri.parse('https://api.altumview.ca/v1.0/cameras?serial_number=$serial'),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  final listJson = jsonDecode(listResp.body);
  log('Camera list response: $listJson');

  // Try to extract camera id from the response

  try {
    final cameras = listJson['data']?['cameras'];

    if (cameras is Map) {
      final arr = cameras['array'];

      if (arr is List && arr.isNotEmpty) {
        final firstCamera = arr[0];

        if (firstCamera is Map && firstCamera['id'] != null) {
          cameraId = firstCamera['id'];
        }
      }
    }
  } catch (e) {
    print("Error extracting cameraId: $e");
  }

  if (cameraId == null) {
    log('⚠️ No existing camera found to delete, continuing...');
    return;
  }

  final deleteResp = await http.delete(
    Uri.parse('https://api.altumview.ca/v1.0/cameras/$cameraId'),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  final deleteJson = jsonDecode(deleteResp.body);
  log('🗑️ Camera $cameraId deleted: $deleteJson');
}

Future<Map<String, dynamic>> factoryReset(String token) => _sendAndWait(
  '/FACTORY_RESET $token',
  ackTimeout: const Duration(seconds: 5),
  resultTimeout: const Duration(seconds: 15),
);



Future<List<Room>> getRooms({required String accessToken}) async {
  final response = await http.get(
    Uri.parse('https://api.altumview.ca/v1.0/rooms'),
    headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
  );
  final json = jsonDecode(response.body);
  final arr  = json['data']?['rooms']?['array'] as List<dynamic>;
  return arr.map((r) => Room.fromJson(r)).toList();
}

Future<void> createImpendingCamera({
  required String serial,
  required String accessToken,
  required int roomId,
  required String firmwareVersion,
})
async {
  try {
    final uri = Uri.parse('https://api.altumview.ca/v1.0/cameras');

    final body = {
      'friendly_name': serial.length > 20 ? serial.substring(0, 20) : serial,
      'room_id': roomId,
      'serial_number': serial,
      'version': firmwareVersion,
      'is_initial_config': true,
    };

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final json = jsonDecode(response.body);

    // 🔍 Debug log
    log('Full camera response: $json');

    // ❌ API failure check
    if (json['success'] != true) {
      throw Exception(json['message'] ?? 'Unknown API error');
    }

    // ✅ Extract camera object
    final camera = json['data']?['camera'];

    if (camera is! Map) {
      throw Exception('Invalid camera response format');
    }

    // ✅ Extract cameraId (if you need it)
    final cameraId = camera['id'];
    log('📸 Camera ID: $cameraId');

    // ✅ Extract mqtt pass
    final mqttPasscode = camera['mqtt_passcode'];

    if (mqttPasscode == null || mqttPasscode.toString().isEmpty) {
      throw Exception('mqtt_passcode missing or empty');
    }

    mqttPass = mqttPasscode;

    log('✅ MQTT pass: $mqttPass');

  } catch (e, stack) {
    log('❌ createImpendingCamera error: $e');
    log(stack.toString());
    rethrow;
  }
}

/* ═══════════════════════════════════════════════════════════
   Log Export — for sending to vendor
   Format matches their reference log exactly
   ═══════════════════════════════════════════════════════════ */

String exportBleLogs() {
  final header = [
    '>>>> Flutter BLE log',
    'Android version: ${Platform.operatingSystemVersion}',
    'flutter_blue_plus library',
    '════════════════════════════════════════',
    '',
  ];
  return [...header, ...bleLog].join('\n');
}









/////////////////////////////////////////////// CALIBRATION PART //////////////////////////////////




//STEP 1 — Generate token

String generatePreviewToken() {
  final rand = DateTime.now().millisecondsSinceEpoch.toString();
  return rand.substring(rand.length - 10); // 10 digit
}






// STEP 2 — Send BLE command
Future<void> enableCalibrationPreview(String token) async {
  final command = '/TOKEN previewToken $token';

  _bleW(_run, '🔧 Enabling preview token: $token');

  await _sendAndWait(
    command,
    ackTimeout: const Duration(seconds: 5),
    resultTimeout: const Duration(seconds: 10),
  );

  log('✅ Preview token set successfully');
}




// STEP 3 — Get preview image

Future<Uint8List?> getPreviewImage({
  required int cameraId,
  required String token,
})
async {
  final url =
      '$_baseApi/cameras/$cameraId/view?preview_token=$token';

  final resp = await http.get(
    Uri.parse(url),
    headers: {'Authorization': 'Bearer $authToken'},
  );

  if (resp.statusCode == 200) {
    log('🖼️ Preview image fetched');
    return resp.bodyBytes;
  } else {
    log('❌ Preview fetch failed: ${resp.statusCode}');
    return null;
  }
}




//  STEP 4 — Call calibrate API
Future<void> calibrateCamera(int cameraId) async {
  final resp = await http.get(
    Uri.parse('$_baseApi/cameras/$cameraId/calibrate'),
    headers: {'Authorization': 'Bearer $authToken'},
  );

  if (resp.statusCode == 200) {
    log('✅ Calibration (floor detection) done');
  } else {
    log('❌ Calibration failed: ${resp.body}');
  }
}


// STEP 5 — SAVE background (CRITICAL )

Future<void> saveBackground(int cameraId) async {
  final resp = await http.get(
    Uri.parse('$_baseApi/cameras/$cameraId/floormask/switch'),
    headers: {'Authorization': 'Bearer $authToken'},
  );

  if (resp.statusCode == 200) {
    log('✅ Background saved successfully');
  } else {
    log('❌ Background save failed: ${resp.body}');
  }
}



// FINAL FULL FLOW

Future<void> runFullCalibration() async {
  try {
    // STEP 1: Generate token
    final token = generatePreviewToken();

    await Future.delayed(const Duration(seconds: 2));
    // STEP 2: Enable preview via BLE
    await enableCalibrationPreview(token);

    await Future.delayed(const Duration(seconds: 2));
    // STEP 3: Get preview image (optional UI)
    await getPreviewImage(cameraId: 11303 ??0, token: token);

    // WAIT (important for stability)
    await Future.delayed(const Duration(seconds: 2));
    // STEP 4: Calibrate
    await calibrateCamera(11303 ?? 0);

    // STEP 5: Save background
    await saveBackground(11303 ?? 0);

    log('🎉 Calibration COMPLETED');
  } catch (e) {
    log(' Calibration flow failed: $e');
  }
}










// ─────────────────────────────────────────────────────────────────────────────
// altum_stream_manager.dart
//
// Complete AltumView skeleton stream manager — drop-in replacement.
//
// KEY FIXES vs previous version:
//   1. Publish token BEFORE subscribing (order matters for broker)
//   2. 500 ms settle delay between publish and subscribe
//   3. keepAlivePeriod reduced to 30 s (60 s caused broker-side timeout)
//   4. _onMqttDisconnected now clears _mqtt before reconnecting
//   5. Reconnect delay increased to 5 s (give broker time to release session)
//   6. onSubscribed / onSubscribeFail callbacks added for diagnostics
//   7. _connectMqtt uses useAlternateWebSocketImplementation = false (explicit)
//   8. _parseBinaryFrame tries BOTH 0-byte and 4-byte header offsets so it
//      works regardless of whether AltumView sends the frame counter or not
//   9. Full logging on every MQTT message so you can see frames arriving
//  10. _running guard prevents double-reconnect race condition
// ─────────────────────────────────────────────────────────────────────────────


const String _baseApi = 'https://api.altumview.ca/v1.0';
const int _jointCount = 18;

// ═════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═════════════════════════════════════════════════════════════════════════════

class SkeletonJoint {
  final double x;
  final double y;

  const SkeletonJoint(this.x, this.y);

  // Camera sends x=0 (left in camera space) to x=1 (right in camera space).
  // The camera image is horizontally mirrored vs the skeleton coords,
  // so we flip: displayX = 1.0 - x
  double get displayX => 1.0 - x;

  @override
  String toString() =>
      'Joint(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

class SkeletonFrame {
  final List<List<SkeletonJoint>> persons;
  final DateTime receivedAt;

  const SkeletonFrame({required this.persons, required this.receivedAt});

  bool get isEmpty => persons.isEmpty;
}

class MqttCredentials {
  final String username;
  final String password;
  final String wssUrl;
  final DateTime expiresAt;

  const MqttCredentials({
    required this.username,
    required this.password,
    required this.wssUrl,
    required this.expiresAt,
  });

  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  factory MqttCredentials.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final account = data['mqtt_account'] as Map<String, dynamic>? ?? data;

    DateTime parseExpiry(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
      if (v is String) {
        return DateTime.tryParse(v) ??
            DateTime.now().add(const Duration(hours: 1));
      }
      return DateTime.now().add(const Duration(hours: 1));
    }

    final password =
        account['passcode'] as String? ?? account['password'] as String? ?? '';
    final wssUrl = data['wss_url'] as String? ??
        account['wss_url'] as String? ??
        '';

    return MqttCredentials(
      username: account['username'] as String? ?? '',
      password: password,
      wssUrl: wssUrl,
      expiresAt: parseExpiry(account['expires_at']),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STREAM MANAGER
// ═════════════════════════════════════════════════════════════════════════════

class AltumSkeletonStreamManager {
  final String accessToken;
  final int cameraId;
  final String serialNumber;

  AltumSkeletonStreamManager({
    required this.accessToken,
    required this.cameraId,
    required this.serialNumber,
  });

  Uint8List? backgroundImage;
  String? _groupId;
  String? _streamToken;
  MqttCredentials? _mqttCreds;

  MqttServerClient? _mqtt;
  Timer? _tokenRefreshTimer;
  Timer? _credRefreshTimer;

  final _frameCtrl = StreamController<SkeletonFrame>.broadcast();
  Stream<SkeletonFrame> get skeletonFrames => _frameCtrl.stream;

  bool _running = false;
  bool _reconnecting = false;

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLIC — start
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> start() async {
    if (_running) return;
    _running = true;
    log('🦴 AltumSkeletonStreamManager: starting…');

    await _checkCameraStatus();
    await _fetchBackground();
    _groupId ??= await _fetchGroupId();

    if (_mqttCreds == null || _mqttCreds!.isExpired) {
      _mqttCreds = await _fetchMqttCredentials();
    }

    _streamToken = await _fetchStreamToken();
    await _connectMqtt();

    _tokenRefreshTimer = Timer.periodic(
      const Duration(seconds: 45),
          (_) => _publishStreamToken(),
    );
    _credRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
          (_) => _checkMqttExpiry(),
    );

    log('✅ AltumSkeletonStreamManager: stream running');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Camera status check
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _checkCameraStatus() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseApi/cameras/$cameraId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      log('📷 Camera status HTTP: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final camera = body['data']?['camera'] as Map<String, dynamic>?;
        if (camera != null) {
          log('📷 Camera name         : ${camera['friendly_name']}');
          log('📷 Camera is_online    : ${camera['is_online']}');
          log('📷 Camera is_streaming : ${camera['is_streaming']}');
          if (camera['is_online'] != true) {
            log('⚠️ CAMERA IS OFFLINE');
          }
        }
      }
    } catch (e) {
      log('⚠️ Camera status check error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 1 — Background image
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _fetchBackground() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseApi/cameras/$cameraId/background'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final url = data['data']?['background_url'] as String?;
      if (url == null || url.isEmpty) return;
      final imgResp = await http.get(Uri.parse(url));
      if (imgResp.statusCode == 200) {
        backgroundImage = imgResp.bodyBytes;
        log('🖼️ Background: ${backgroundImage!.length} bytes');
      }
    } catch (e) {
      log('⚠️ Background fetch error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 2 — Group ID
  // ═══════════════════════════════════════════════════════════════════════
  Future<String> _fetchGroupId() async {
    final resp = await http.get(
      Uri.parse('$_baseApi/info'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final groupId = body['data']?['group_id']?.toString();
    if (groupId == null) throw Exception('group_id missing from /info');
    log('📦 Group ID: $groupId');
    return groupId;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 3 — MQTT credentials
  // ═══════════════════════════════════════════════════════════════════════
  Future<MqttCredentials> _fetchMqttCredentials() async {
    final resp = await http.get(
      Uri.parse('$_baseApi/mqttAccount'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    log('📡 mqttAccount raw: $body');

    if (body['success'] != true) {
      throw Exception('mqttAccount failed: ${body['message']}');
    }

    final creds = MqttCredentials.fromJson(body);
    if (creds.username.isEmpty ||
        creds.password.isEmpty ||
        creds.wssUrl.isEmpty) {
      throw Exception(
        'MQTT creds incomplete: user=${creds.username} '
            'pass=${creds.password.isEmpty ? "EMPTY" : "ok"} wss=${creds.wssUrl}',
      );
    }
    log('🔑 MQTT: user=${creds.username} wss=${creds.wssUrl}');
    return creds;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 4 — Stream token
  // ═══════════════════════════════════════════════════════════════════════
  Future<String> _fetchStreamToken() async {
    final resp = await http.get(
      Uri.parse('$_baseApi/cameras/$cameraId/streamtoken'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    log('📥 streamtoken status: ${resp.statusCode}');
    log('📥 streamtoken body  : ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('streamtoken failed: ${resp.statusCode} ${resp.body}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('streamtoken: data field missing');

    final raw = data['stream_token'] ?? data['streamToken'];
    if (raw == null) throw Exception('stream_token missing. data=$data');

    final token = raw.toString();
    log('🎫 Stream token: $token');
    return token;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 5 — MQTT connect
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _connectMqtt() async {
    final creds = _mqttCreds!;
    final fullUrl = creds.wssUrl;
    final port =
    Uri.parse(fullUrl).hasPort ? Uri.parse(fullUrl).port : 8084;
    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';

    log('🔌 MQTT → $fullUrl  port=$port');

    _mqtt = MqttServerClient.withPort(fullUrl, clientId, port);
    _mqtt!.useWebSocket = true;
    _mqtt!.useAlternateWebSocketImplementation = false;
    _mqtt!.websocketProtocols = ['mqtt'];
    _mqtt!.secure = false;
    _mqtt!.keepAlivePeriod = 30;
    _mqtt!.connectTimeoutPeriod = 10000;

    _mqtt!.onConnected = () => log('✅ MQTT onConnected');
    _mqtt!.onDisconnected = _onMqttDisconnected;
    _mqtt!.onSubscribed = (topic) => log('✅ Subscribed OK: $topic');
    _mqtt!.onSubscribeFail = (topic) => log('❌ Subscribe FAILED: $topic');

    _mqtt!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withProtocolName('MQTT')
        .withProtocolVersion(4)
        .authenticateAs(creds.username, creds.password)
        .startClean();

    try {
      await _mqtt!.connect();
    } catch (e) {
      log('❌ MQTT connect error: $e');
      rethrow;
    }

    if (_mqtt!.connectionStatus?.state != MqttConnectionState.connected) {
      throw Exception('MQTT not connected: ${_mqtt!.connectionStatus}');
    }
    log('✅ MQTT connected');

    _publishStreamToken();
    await Future.delayed(const Duration(milliseconds: 1000));

    final topic = _skeletonTopic();
    log('📡 Subscribing (QoS 0): $topic');
    _mqtt!.subscribe(topic, MqttQos.atMostOnce);
    _mqtt!.updates?.listen(_onMqttMessage);
  }

  void _publishStreamToken() {
    if (_mqtt?.connectionStatus?.state != MqttConnectionState.connected)
      return;
    if (_streamToken == null || _groupId == null) return;

    final topic =
        'mobile/$_groupId/camera/$serialNumber/token/mobileStreamToken';
    final builder = MqttClientPayloadBuilder()..addUTF8String(_streamToken!);
    _mqtt!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    log('📤 Token published → $topic  payload=$_streamToken');
  }

  void _onMqttDisconnected() {
    if (!_running) return;
    if (_reconnecting) return;
    _reconnecting = true;
    log('⚠️ MQTT disconnected — reconnecting in 5 s…');
    Future.delayed(const Duration(seconds: 5), () async {
      if (!_running) {
        _reconnecting = false;
        return;
      }
      _mqtt = null;
      try {
        await _connectMqtt();
        _reconnecting = false;
      } catch (e) {
        _reconnecting = false;
        log('❌ Reconnect failed: $e — retry in 15 s');
        Future.delayed(const Duration(seconds: 15), () {
          if (_running) _onMqttDisconnected();
        });
      }
    });
  }

  Future<void> _checkMqttExpiry() async {
    if (_mqttCreds == null || !_mqttCreds!.isExpired) return;
    log('⏰ MQTT creds expired — full reconnect');
    _tokenRefreshTimer?.cancel();
    _credRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    _credRefreshTimer = null;
    _mqttCreds = null;
    _running = false;
    if (_mqtt?.connectionStatus?.state == MqttConnectionState.connected) {
      _mqtt!.disconnect();
    }
    _mqtt = null;
    await start();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MQTT message handler
  // ═══════════════════════════════════════════════════════════════════════
  void _onMqttMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final payload = msg.payload as MqttPublishMessage;
      final bytes =
      Uint8List.fromList(payload.payload.message.toList());
      log('📦 Frame: ${bytes.length} bytes on ${msg.topic}');

      // Need at least the 8-byte frame header
      if (bytes.length < 8) {
        log('⚠️ Frame too short (${bytes.length} bytes)');
        continue;
      }

      final frame = _parseBinaryFrame(bytes);
      log('👤 Persons parsed: ${frame.persons.length}');
      if (!_frameCtrl.isClosed) _frameCtrl.add(frame);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Binary parser — faithfully mirrors C# RealTimeSkeletonProcessor
  //
  // Wire format (all values little-endian):
  //
  //   [0..3]   uint32  frameNumber
  //   [4..7]   uint32  numberOfPeople
  //
  //   Per person block — 152 bytes, startIndex = 8 + (152 * i):
  //     [+0 .. +3]   uint32  personId
  //     [+4 .. +7]   uint32  trackerId
  //     [+8 .. +79]  float32 × 18  →  ALL X coordinates  (joint 0..17)
  //     [+80..+151]  float32 × 18  →  ALL Y coordinates  (joint 0..17)
  //
  // The C# reads joint data as a flat list of 36 floats (j += 4),
  // then splits:  XCoords = xyCoords[0..17], YCoords = xyCoords[18..35]
  // This means the first 72 bytes after the IDs are all X values,
  // the next 72 bytes are all Y values — NOT interleaved pairs.
  // ═══════════════════════════════════════════════════════════════════════
  SkeletonFrame _parseBinaryFrame(Uint8List bytes) {
    final persons = <List<SkeletonJoint>>[];

    final bd = ByteData.view(
        bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

    // Read frame header
    final frameNum = bd.getUint32(0, Endian.little);
    final personCount = bd.getUint32(4, Endian.little);

    log('🎞️ Frame=$frameNum  personCount=$personCount  bytes=${bytes.length}');

    // Guard against garbage personCount
    if (personCount == 0 || personCount > 20) {
      if (personCount != 0) {
        log('⚠️ personCount=$personCount looks invalid, skipping');
      }
      return SkeletonFrame(persons: persons, receivedAt: DateTime.now());
    }

    for (int i = 0; i < personCount; i++) {
      // Exactly matches C#:  startIndex = 8 + (152 * i)
      final startIndex = 8 + (152 * i);
      final endIndex = startIndex + 152;

      if (endIndex > bytes.length) {
        log('⚠️ Person $i out of bounds (need $endIndex, have ${bytes.length})');
        break;
      }

      final personId = bd.getUint32(startIndex, Endian.little);
      final trackerId = bd.getUint32(startIndex + 4, Endian.little);

      // Read all 36 floats sequentially — exactly like C#:
      //   for (int j = startIndex + 8; j < endIndex; j += 4) { xyCoords.Add(...) }
      // 144 bytes / 4 bytes per float = 36 floats total
      final xyCoords = <double>[];
      for (int j = startIndex + 8; j < endIndex; j += 4) {
        xyCoords.add(bd.getFloat32(j, Endian.little).toDouble());
      }

      // Split exactly like C#:
      //   XCoords = xyCoords.GetRange(0, 18)   ← first 18 floats = all X
      //   YCoords = xyCoords.GetRange(18, 18)  ← next  18 floats = all Y
      final xCoords = xyCoords.sublist(0, 18);
      final yCoords = xyCoords.sublist(18, 36);

      log('  person[$i] id=$personId tracker=$trackerId');
      log('  X[0]=${xCoords[0].toStringAsFixed(3)} X[1]=${xCoords[1].toStringAsFixed(3)}');
      log('  Y[0]=${yCoords[0].toStringAsFixed(3)} Y[1]=${yCoords[1].toStringAsFixed(3)}');

      // Build the 18 joints
      final joints = <SkeletonJoint>[];
      for (int j = 0; j < _jointCount; j++) {
        joints.add(SkeletonJoint(
          xCoords[j].clamp(0.0, 1.0),
          yCoords[j].clamp(0.0, 1.0),
        ));
      }

      // Only add person if at least one joint has actual data
      final hasData = joints.any((jt) => jt.x != 0.0 || jt.y != 0.0);
      if (hasData) persons.add(joints);
    }

    return SkeletonFrame(persons: persons, receivedAt: DateTime.now());
  }

  String _skeletonTopic() =>
      'mobileClient/$_groupId/camera/$serialNumber/skeleton/$_streamToken';
}