// ─────────────────────────────────────────────────────────────────────────────
// features/altum_view/presentation/providers/camera_provider.dart
//
// Drives the main dashboard screen — camera list, online status, refresh.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:altum_view_sdk/features/camera/domain/models/camera_model.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/camera_repository.dart';

class CameraProvider extends ChangeNotifier {
  final CameraRepository _repo;
  CameraProvider(this._repo);

  ViewState<List<CameraModel>> cameraListState  = const IdleState();
  ViewState<CameraModel>       cameraDetailState = const IdleState();

  List<CameraModel> get cameras =>
      cameraListState is SuccessState<List<CameraModel>>
          ? (cameraListState as SuccessState<List<CameraModel>>).data
          : [];

  CameraModel? get selectedCamera =>
      cameraDetailState is SuccessState<CameraModel>
          ? (cameraDetailState as SuccessState<CameraModel>).data
          : null;

  // ── Load all cameras ───────────────────────────────────────────────────────

  Future<void> loadCameras() async {
    cameraListState = const LoadingState();
    notifyListeners();
    try {
      final data      = await _repo.getCameras();
      cameraListState = SuccessState(data);
    } catch (e) {
      cameraListState = ErrorState(e.toString());
    }
    notifyListeners();
  }

  // ── Load single camera (for detail / dashboard header) ────────────────────

  Future<void> loadCameraById(int id) async {
    cameraDetailState = const LoadingState();
    notifyListeners();
    try {
      final camera      = await _repo.getCameraById(id);
      cameraDetailState = SuccessState(camera);
    } catch (e) {
      cameraDetailState = ErrorState(e.toString());
    }
    notifyListeners();
  }

  // ── Refresh (pull-to-refresh) ──────────────────────────────────────────────

  Future<void> refresh() => loadCameras();
}