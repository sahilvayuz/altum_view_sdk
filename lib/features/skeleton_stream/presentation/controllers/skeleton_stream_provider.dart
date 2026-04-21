// ─────────────────────────────────────────────────────────────────────────────
// features/skeleton_stream/presentation/controllers/skeleton_stream_provider.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:typed_data';

import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:altum_view_sdk/features/skeleton_stream/domain/repository/skeleton_stream_repository.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/skeleton_model.dart';

class SkeletonStreamProvider extends ChangeNotifier {
  final SkeletonStreamRepository _repo;
  SkeletonStreamProvider(this._repo);

  ViewState<void> streamState = const IdleState();
  SkeletonFrame? latestFrame;
  Uint8List? backgroundImage;
  SkeletonStreamStatus streamStatus = SkeletonStreamStatus.idle;

  StreamSubscription<SkeletonFrame>? _frameSub;
  StreamSubscription<SkeletonStreamStatus>? _statusSub;

  bool get isStreaming =>
      streamState is LoadingState || streamState is SuccessState;

  // ── Start stream ───────────────────────────────────────────────────────────

  Future<void> startStream() async {
    if (isStreaming) return;

    streamState = const LoadingState();
    streamStatus = SkeletonStreamStatus.connecting;
    notifyListeners();

    try {
      await _repo.start();

      // Camera offline — manager stopped itself, surface the status
      if (_repo.cameraOffline) {
        streamState = const ErrorState('Camera is offline');
        streamStatus = SkeletonStreamStatus.cameraOffline;
        notifyListeners();
        return;
      }

      backgroundImage = _repo.backgroundImage;
      streamState = const SuccessState(null);
      streamStatus = SkeletonStreamStatus.live;
      notifyListeners();

      // Frame subscription
      _frameSub = _repo.skeletonFrames.listen(
            (frame) {
          latestFrame = frame;
          notifyListeners();
        },
        onError: (e) {
          streamState = ErrorState(e.toString());
          streamStatus = SkeletonStreamStatus.error;
          notifyListeners();
        },
      );

      // Status subscription (silence watchdog, republish, etc.)
      _statusSub = _repo.statusStream.listen((status) {
        streamStatus = status;
        if (status == SkeletonStreamStatus.waitingForFrame ||
            status == SkeletonStreamStatus.waitingRepublish) {
          latestFrame = null;
        }
        notifyListeners();
      });
    } catch (e) {
      streamState = ErrorState(e.toString());
      streamStatus = SkeletonStreamStatus.error;
      notifyListeners();
    }
  }

  // ── Stop stream ────────────────────────────────────────────────────────────

  Future<void> stopStream() async {
    await _frameSub?.cancel();
    await _statusSub?.cancel();
    _frameSub = null;
    _statusSub = null;
    await _repo.stop();
    streamState = const IdleState();
    streamStatus = SkeletonStreamStatus.idle;
    latestFrame = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _frameSub?.cancel();
    _statusSub?.cancel();
    _repo.stop();
    super.dispose();
  }
}