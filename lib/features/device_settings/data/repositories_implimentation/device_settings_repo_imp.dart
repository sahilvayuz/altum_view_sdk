// ─────────────────────────────────────────────────────────────────────────────
// features/device_settings/data/repositories/device_settings_repository_impl.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/networking/app_exception.dart';
import 'package:altum_view_sdk/features/device_settings/data/data_source/device_settings_remote_data_source.dart';
import 'package:altum_view_sdk/features/device_settings/domain/models/device_settings_model.dart';
import 'package:altum_view_sdk/features/device_settings/domain/repositories/device_settings_repository.dart';
import 'package:dio/dio.dart';


class DeviceSettingsRepositoryImpl implements DeviceSettingsRepository {
  final DeviceSettingsRemoteDataSource _source;
  DeviceSettingsRepositoryImpl(this._source);

  @override
  Future<DeviceSettingsModel> getSettings(int cameraId) =>
      _safe(() => _source.getSettings(cameraId));

  @override
  Future<void> updateSettings(int cameraId, DeviceSettingsModel settings) =>
      _safe(() => _source.updateSettings(cameraId, settings));

  Future<T> _safe<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : ApiException(e.message ?? 'Unknown error');
    }
  }
}