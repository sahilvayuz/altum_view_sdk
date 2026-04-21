// ─────────────────────────────────────────────────────────────────────────────
// features/altum_view/domain/repositories/camera_repository.dart
// ─────────────────────────────────────────────────────────────────────────────


import 'package:altum_view_sdk/features/camera/domain/models/camera_model.dart';

abstract interface class CameraRepository {
  Future<List<CameraModel>> getCameras();
  Future<CameraModel>       getCameraById(int id);
}