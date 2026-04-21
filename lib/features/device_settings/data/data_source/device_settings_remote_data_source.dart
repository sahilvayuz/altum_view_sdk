// ─────────────────────────────────────────────────────────────────────────────
// features/device_settings/data/sources/device_settings_remote_data_source.dart
//
// Fetches and updates camera/device settings via the Altum API.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:altum_view_sdk/features/device_settings/domain/models/device_settings_model.dart';


abstract interface class DeviceSettingsRemoteDataSource {
  Future<DeviceSettingsModel> getSettings(int cameraId);
  Future<void>                updateSettings(int cameraId, DeviceSettingsModel settings);
}

class DeviceSettingsRemoteDataSourceImpl implements DeviceSettingsRemoteDataSource {
  final DioClient _client;
  DeviceSettingsRemoteDataSourceImpl(this._client);

  @override
  Future<DeviceSettingsModel> getSettings(int cameraId) async {
    final resp = await _client.get(ApiConstants.cameraById(cameraId));
    log('⚙️  GET /cameras/$cameraId → ${resp.statusCode}');
    final camera = resp.data['data']?['camera'] as Map<String, dynamic>?;
    if (camera == null) throw Exception('Camera data missing in response');
    return DeviceSettingsModel.fromJson(camera);
  }

  @override
  Future<void> updateSettings(int cameraId, DeviceSettingsModel settings) async {
    await _client.patch(
      ApiConstants.cameraById(cameraId),
      data: settings.toJson(),
    );
    log('✅ Settings updated for camera $cameraId');
  }
}