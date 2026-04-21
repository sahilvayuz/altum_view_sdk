// ─────────────────────────────────────────────────────────────────────────────
// features/altum_view/data/repositories/camera_repository_impl.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/networking/app_exception.dart';
import 'package:altum_view_sdk/features/camera/data/data_source/camera_remote_data_source.dart';
import 'package:altum_view_sdk/features/camera/domain/models/camera_model.dart';
import 'package:altum_view_sdk/features/camera/domain/repositories/camera_repository.dart';
import 'package:dio/dio.dart';

class CameraRepositoryImpl implements CameraRepository {
  final CameraRemoteDataSource _source;
  CameraRepositoryImpl(this._source);

  @override
  Future<List<CameraModel>> getCameras() => _safe(_source.getCameras);

  @override
  Future<CameraModel> getCameraById(int id) =>
      _safe(() => _source.getCameraById(id));

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