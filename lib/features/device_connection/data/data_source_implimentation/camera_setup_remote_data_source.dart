// ─────────────────────────────────────────────────────────────────────────────
// features/device_connection/data/sources/camera_setup_remote_data_source.dart
//
// Cloud API calls required during the device setup flow:
//   • Fetch Bluetooth token (optionally deletes stale camera first)
//   • Register / delete camera
//   • Fetch rooms list (needed to pick roomId)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:altum_view_sdk/features/device_connection/domain/models/device_setup_result_model.dart';
import 'package:altum_view_sdk/features/rooms/domain/models/room_model.dart';

abstract interface class CameraSetupRemoteDataSource {
  Future<String>         getBluetoothToken(String serialNumber);
  Future<void>           deleteCamera(String serialNumber);
  Future<List<RoomModel>> getRoomsForSetup();
  Future<CameraSetupResultModel> createCamera({
    required String serial,
    required String firmwareVersion,
    required int    roomId,
  });
  Future<void> fetchGroupInfo(); // populates group_id used in /SET
}

class CameraSetupRemoteDataSourceImpl implements CameraSetupRemoteDataSource {
  final DioClient _client;

  String? groupId; // populated by fetchGroupInfo()
  int?    cameraId;

  CameraSetupRemoteDataSourceImpl(this._client);

  // ── Bluetooth token ────────────────────────────────────────────────────────

  @override
  Future<String> getBluetoothToken(String serialNumber) async {
    final resp = await _client.get(ApiConstants.bluetoothToken(serialNumber));
    final data = resp.data as Map<String, dynamic>;

    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Token request failed');
    }

    final payload      = data['data'] as Map<String, dynamic>;
    final cameraExists = payload['camera_exist'] == true;

    if (cameraExists) {
      log('⚠️  Camera already exists — deleting before fresh registration');
      await deleteCamera(serialNumber);

      // Fresh token after deletion
      final freshResp = await _client.get(ApiConstants.bluetoothToken(serialNumber));
      final freshData = freshResp.data as Map<String, dynamic>;
      if (freshData['success'] != true) {
        throw Exception(freshData['message'] ?? 'Fresh token request failed');
      }
      final freshToken = freshData['data']['bluetooth_token'];
      if (freshToken == null) throw Exception('bluetooth_token missing in fresh response');
      return freshToken.toString();
    }

    final token = payload['bluetooth_token'];
    if (token == null) throw Exception('bluetooth_token missing in response');
    return token.toString();
  }

  // ── Delete camera ──────────────────────────────────────────────────────────

  @override
  Future<void> deleteCamera(String serialNumber) async {
    final listResp = await _client.get(ApiConstants.camerasBy(serialNumber));
    final cameras  = listResp.data['data']?['cameras'];

    if (cameras is Map) {
      final arr = cameras['array'];
      if (arr is List && arr.isNotEmpty) {
        cameraId = (arr[0] as Map)['id'];
      }
    }

    if (cameraId == null) {
      log('⚠️  No existing camera to delete, continuing...');
      return;
    }

    await _client.delete(ApiConstants.cameraById(cameraId!));
    log('🗑️  Camera $cameraId deleted');
  }

  // ── Rooms ──────────────────────────────────────────────────────────────────

  @override
  Future<List<RoomModel>> getRoomsForSetup() async {
    final resp = await _client.get(ApiConstants.rooms);
    final arr  = resp.data['data']?['rooms']?['array'] as List? ?? [];
    return arr.cast<Map<String, dynamic>>().map(RoomModel.fromJson).toList();
  }

  // ── Create camera ──────────────────────────────────────────────────────────

  @override
  Future<CameraSetupResultModel> createCamera({
    required String serial,
    required String firmwareVersion,
    required int    roomId,
  }) async {
    final resp = await _client.post(
      ApiConstants.cameras,
      data: {
        'friendly_name':    serial.length > 20 ? serial.substring(0, 20) : serial,
        'room_id':          roomId,
        'serial_number':    serial,
        'version':          firmwareVersion,
        'is_initial_config': true,
      },
    );

    final json = resp.data as Map<String, dynamic>;
    if (json['success'] != true) {
      throw Exception(json['message'] ?? 'Unknown API error');
    }

    final camera = json['data']?['camera'] as Map<String, dynamic>?;
    if (camera == null) throw Exception('Invalid camera response format');

    final mqttPasscode = camera['mqtt_passcode'];
    if (mqttPasscode == null || mqttPasscode.toString().isEmpty) {
      throw Exception('mqtt_passcode missing or empty');
    }

    log('📸 Camera ID: ${camera['id']}  MQTT pass: $mqttPasscode');
    return CameraSetupResultModel(
      cameraId:     (camera['id'] as num).toInt(),
      mqttPasscode: mqttPasscode.toString(),
    );
  }

  // ── Group ID ───────────────────────────────────────────────────────────────

  @override
  Future<void> fetchGroupInfo() async {
    final resp = await _client.get(ApiConstants.info);
    groupId = resp.data['data']?['group_id']?.toString();
    log('📦 Group ID: $groupId');
  }
}