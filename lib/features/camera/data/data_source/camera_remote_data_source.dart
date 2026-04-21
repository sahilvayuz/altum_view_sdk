// ─────────────────────────────────────────────────────────────────────────────
// features/altum_view/data/sources/camera_remote_data_source.dart
//
// Fetches the camera list for the main dashboard.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';

import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:altum_view_sdk/features/camera/domain/models/camera_model.dart';

abstract interface class CameraRemoteDataSource {
  Future<List<CameraModel>> getCameras();
  Future<CameraModel>       getCameraById(int id);
}

class CameraRemoteDataSourceImpl implements CameraRemoteDataSource {
  final DioClient _client;
  CameraRemoteDataSourceImpl(this._client);

  @override
  Future<List<CameraModel>> getCameras() async {
    final resp = await _client.get(ApiConstants.cameras,);
    log('📷 GET /cameras → ${resp.statusCode}');
    final arr  = resp.data['data']?['cameras']?['array'] as List? ?? [];
    return arr.cast<Map<String, dynamic>>().map(CameraModel.fromJson).toList();
  }

  @override
  Future<CameraModel> getCameraById(int id) async {
    final resp   = await _client.get(ApiConstants.cameraById(id));
    final camera = resp.data['data']?['camera'] as Map<String, dynamic>?;
    if (camera == null) throw Exception('Camera not found');
    return CameraModel.fromJson(camera);
  }
}