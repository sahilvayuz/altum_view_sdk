// ─────────────────────────────────────────────────────────────────────────────
// features/skeleton_stream/data/sources/skeleton_stream_manager.dart
//
// KEY FIXES:
//   1. _fetchBackground: background_url is a pre-signed S3/CDN URL.
//      Fetch it with a plain Dio GET with NO baseUrl prefix and NO auth header.
//      Use a naked Dio() instance for this one call only (exactly like the
//      working http.get(Uri.parse(url)) in the reference code).
//   2. stop() sets _running=false and cancels ALL timers before disconnecting,
//      so _onMqttDisconnected's reconnect guard fires correctly and logs stop.
//   3. StreamStatus emitted on every state change so the UI can react.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../../domain/models/skeleton_model.dart';

const int _jointCount = 18;

// ── StreamStatus ──────────────────────────────────────────────────────────────

enum StreamStatus {
  idle,
  connecting,
  live,
  waitingForFrame,  // connected but no frame in last 3 s
  republishing,     // MQTT dropped, token re-sent, waiting for frames
  offline,          // camera is_online=false
  error,
}

// ── Manager ───────────────────────────────────────────────────────────────────

class SkeletonStreamManager {
  final DioClient _client;
  final int       cameraId;
  final String    serialNumber;

  SkeletonStreamManager({
    required DioClient client,
    required this.cameraId,
    required this.serialNumber,
  }) : _client = client;

  Uint8List?   backgroundImage;
  StreamStatus status = StreamStatus.idle;

  String?           _groupId;
  String?           _streamToken;
  MqttCredentials?  _mqttCreds;
  MqttServerClient? _mqtt;

  Timer? _tokenRefreshTimer;
  Timer? _credRefreshTimer;
  Timer? _frameTimeoutTimer;

  final _frameCtrl  = StreamController<SkeletonFrame>.broadcast();
  final _statusCtrl = StreamController<StreamStatus>.broadcast();

  Stream<SkeletonFrame> get skeletonFrames => _frameCtrl.stream;
  Stream<StreamStatus>  get statusStream   => _statusCtrl.stream;

  bool _running      = false;
  bool _reconnecting = false;

  void _setStatus(StreamStatus s) {
    status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  // ── start ─────────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _setStatus(StreamStatus.connecting);
    log('🦴 SkeletonStreamManager: starting…');

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

    _setStatus(StreamStatus.waitingForFrame);
    log('✅ SkeletonStreamManager: stream running');
  }

  // ── stop ──────────────────────────────────────────────────────────────────
  // Sets _running=false FIRST so _onMqttDisconnected's guard kills reconnect.

  Future<void> stop() async {
    _running = false;                         // ← must be first
    _tokenRefreshTimer?.cancel();
    _credRefreshTimer?.cancel();
    _frameTimeoutTimer?.cancel();
    _tokenRefreshTimer = null;
    _credRefreshTimer  = null;
    _frameTimeoutTimer = null;

    if (_mqtt?.connectionStatus?.state == MqttConnectionState.connected) {
      _mqtt!.disconnect();
    }
    _mqtt = null;

    _setStatus(StreamStatus.idle);

    if (!_frameCtrl.isClosed)  await _frameCtrl.close();
    if (!_statusCtrl.isClosed) await _statusCtrl.close();

    log('🛑 SkeletonStreamManager: stopped');
  }

  // ── Step 1 — Camera status ────────────────────────────────────────────────

  Future<void> _checkCameraStatus() async {
    try {
      final resp   = await _client.get(ApiConstants.cameraById(cameraId));
      final camera = resp.data['data']?['camera'] as Map<String, dynamic>?;
      if (camera != null) {
        log('📷 name=${camera['friendly_name']}  '
            'online=${camera['is_online']}  '
            'streaming=${camera['is_streaming']}');
        if (camera['is_online'] != true) {
          log('⚠️  CAMERA IS OFFLINE');
          _setStatus(StreamStatus.offline);
        }
      }
    } catch (e) {
      log('⚠️  Camera status check error: $e');
    }
  }

  // ── Step 2 — Background image ─────────────────────────────────────────────
  //
  // FIX: background_url is a pre-signed S3/CDN URL with auth in its query
  // string. It must be fetched with:
  //   • The FULL URL (no baseUrl prefix)
  //   • NO Authorization header (that would break the S3 signature)
  //
  // Use a naked Dio() instance — identical to the reference code which uses
  // http.get(Uri.parse(url)) with no headers.

  Future<void> _fetchBackground() async {
    try {
      // Step 2a — get the pre-signed URL from our API
      final resp = await _client.get(ApiConstants.cameraBackground(cameraId));
      final url  = resp.data['data']?['background_url'] as String?;
      if (url == null || url.isEmpty) {
        log('⚠️  No background_url in response');
        return;
      }
      log('🖼️  Fetching background from: $url');

      // Step 2b — fetch the image with a plain, unauthenticated GET
      // (pre-signed URL must NOT have an Authorization header)
      final imgResp = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (imgResp.statusCode == 200 && imgResp.data != null) {
        backgroundImage = Uint8List.fromList(imgResp.data!);
        log('🖼️  Background: ${backgroundImage!.length} bytes ✅');
      } else {
        log('⚠️  Background fetch: unexpected status ${imgResp.statusCode}');
      }
    } catch (e) {
      log('⚠️  Background fetch error: $e');
    }
  }

  // ── Step 3 — Group ID ─────────────────────────────────────────────────────

  Future<String> _fetchGroupId() async {
    final resp    = await _client.get(ApiConstants.info);
    final groupId = resp.data['data']?['group_id']?.toString();
    if (groupId == null) throw Exception('group_id missing from /info');
    log('📦 Group ID: $groupId');
    return groupId;
  }

  // ── Step 4 — MQTT credentials ─────────────────────────────────────────────

  Future<MqttCredentials> _fetchMqttCredentials() async {
    final resp = await _client.get(ApiConstants.mqttAccount);
    final body = resp.data as Map<String, dynamic>;
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
    log('🔑 MQTT: user=${creds.username}  wss=${creds.wssUrl}');
    return creds;
  }

  // ── Step 5 — Stream token ─────────────────────────────────────────────────

  Future<String> _fetchStreamToken() async {
    final resp = await _client.get(ApiConstants.cameraStreamToken(cameraId));
    log('📥 streamtoken status: ${resp.statusCode}');

    final data = resp.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('streamtoken: data field missing');

    final raw = data['stream_token'] ?? data['streamToken'];
    if (raw == null) throw Exception('stream_token missing. data=$data');

    final token = raw.toString();
    log('🎫 Stream token: $token');
    return token;
  }

  // ── Step 6 — MQTT connect ─────────────────────────────────────────────────

  Future<void> _connectMqtt() async {
    final creds    = _mqttCreds!;
    final fullUrl  = creds.wssUrl;
    final port     = Uri.parse(fullUrl).hasPort
        ? Uri.parse(fullUrl).port
        : 8084;
    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';

    log('🔌 MQTT → $fullUrl  port=$port');

    _mqtt = MqttServerClient.withPort(fullUrl, clientId, port);
    _mqtt!.useWebSocket                       = true;
    _mqtt!.useAlternateWebSocketImplementation = false;
    _mqtt!.websocketProtocols                 = ['mqtt'];
    _mqtt!.secure                             = false;
    _mqtt!.keepAlivePeriod                    = 30;
    _mqtt!.connectTimeoutPeriod               = 10000;
    _mqtt!.onConnected     = () => log('✅ MQTT onConnected');
    _mqtt!.onDisconnected  = _onMqttDisconnected;
    _mqtt!.onSubscribed    = (t) => log('✅ Subscribed OK: $t');
    _mqtt!.onSubscribeFail = (t) => log('❌ Subscribe FAILED: $t');

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
    if (_mqtt?.connectionStatus?.state != MqttConnectionState.connected) return;
    if (_streamToken == null || _groupId == null) return;

    final topic   =
        'mobile/$_groupId/camera/$serialNumber/token/mobileStreamToken';
    final builder = MqttClientPayloadBuilder()..addUTF8String(_streamToken!);
    _mqtt!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    log('📤 Token published → $topic');
  }

  void _onMqttDisconnected() {
    // _running is false when stop() was called — do NOT reconnect
    if (!_running || _reconnecting) return;
    _reconnecting = true;
    _setStatus(StreamStatus.republishing);
    log('⚠️  MQTT disconnected — reconnecting in 5 s…');

    Future.delayed(const Duration(seconds: 5), () async {
      if (!_running) { _reconnecting = false; return; }
      _mqtt = null;
      try {
        await _connectMqtt();
        _reconnecting = false;
        _setStatus(StreamStatus.waitingForFrame);
      } catch (e) {
        _reconnecting = false;
        log('❌ Reconnect failed: $e — retry in 15 s');
        Future.delayed(
          const Duration(seconds: 15),
              () { if (_running) _onMqttDisconnected(); },
        );
      }
    });
  }

  Future<void> _checkMqttExpiry() async {
    if (_mqttCreds == null || !_mqttCreds!.isExpired) return;
    log('⏰ MQTT creds expired — full reconnect');
    _tokenRefreshTimer?.cancel();
    _credRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    _credRefreshTimer  = null;
    _mqttCreds         = null;
    _running           = false;
    if (_mqtt?.connectionStatus?.state == MqttConnectionState.connected) {
      _mqtt!.disconnect();
    }
    _mqtt = null;
    await start();
  }

  // ── MQTT message handler ──────────────────────────────────────────────────

  void _onMqttMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final payload = msg.payload as MqttPublishMessage;
      final bytes   = Uint8List.fromList(payload.payload.message.toList());
      log('📦 Frame: ${bytes.length} bytes on ${msg.topic}');

      if (bytes.length < 8) {
        log('⚠️  Frame too short (${bytes.length} bytes)');
        continue;
      }

      final frame = _parseBinaryFrame(bytes);
      log('👤 Persons parsed: ${frame.persons.length}');
      if (!_frameCtrl.isClosed) _frameCtrl.add(frame);

      // Live — reset 3 s watchdog
      _setStatus(StreamStatus.live);
      _frameTimeoutTimer?.cancel();
      _frameTimeoutTimer = Timer(const Duration(seconds: 3), () {
        if (_running) _setStatus(StreamStatus.waitingForFrame);
      });
    }
  }

  // ── Binary parser ─────────────────────────────────────────────────────────

  SkeletonFrame _parseBinaryFrame(Uint8List bytes) {
    final persons = <List<SkeletonJoint>>[];
    final bd      = ByteData.view(
        bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

    final frameNum    = bd.getUint32(0, Endian.little);
    final personCount = bd.getUint32(4, Endian.little);
    log('🎞️  Frame=$frameNum  personCount=$personCount  bytes=${bytes.length}');

    if (personCount == 0 || personCount > 20) {
      if (personCount != 0) {
        log('⚠️  personCount=$personCount looks invalid, skipping');
      }
      return SkeletonFrame(persons: persons, receivedAt: DateTime.now());
    }

    for (int i = 0; i < personCount; i++) {
      final startIndex = 8 + (152 * i);
      final endIndex   = startIndex + 152;

      if (endIndex > bytes.length) {
        log('⚠️  Person $i out of bounds (need $endIndex, have ${bytes.length})');
        break;
      }

      final personId  = bd.getUint32(startIndex,     Endian.little);
      final trackerId = bd.getUint32(startIndex + 4, Endian.little);

      final xyCoords = <double>[];
      for (int j = startIndex + 8; j < endIndex; j += 4) {
        xyCoords.add(bd.getFloat32(j, Endian.little).toDouble());
      }

      final xCoords = xyCoords.sublist(0, 18);
      final yCoords = xyCoords.sublist(18, 36);

      log('  person[$i] id=$personId tracker=$trackerId');
      log('  X[0]=${xCoords[0].toStringAsFixed(3)} '
          'Y[0]=${yCoords[0].toStringAsFixed(3)}');

      final joints = <SkeletonJoint>[];
      for (int j = 0; j < _jointCount; j++) {
        joints.add(SkeletonJoint(
          xCoords[j].clamp(0.0, 1.0),
          yCoords[j].clamp(0.0, 1.0),
        ));
      }

      final hasData = joints.any((jt) => jt.x != 0.0 || jt.y != 0.0);
      if (hasData) persons.add(joints);
    }

    return SkeletonFrame(persons: persons, receivedAt: DateTime.now());
  }

  String _skeletonTopic() =>
      'mobileClient/$_groupId/camera/$serialNumber/skeleton/$_streamToken';
}