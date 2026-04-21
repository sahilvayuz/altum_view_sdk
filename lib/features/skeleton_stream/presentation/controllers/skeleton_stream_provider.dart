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

  ViewState<void>   streamState     = const IdleState();
  SkeletonFrame?    latestFrame;
  Uint8List?        backgroundImage;
  StreamSubscription<SkeletonFrame>? _subscription;

  bool get isStreaming =>
      streamState is LoadingState || streamState is SuccessState;

  // ── Start stream ───────────────────────────────────────────────────────────

  Future<void> startStream() async {
    if (isStreaming) return;

    streamState = const LoadingState();
    notifyListeners();

    try {
      await _repo.start();
      backgroundImage = _repo.backgroundImage;
      streamState     = const SuccessState(null);
      notifyListeners();

      _subscription = _repo.skeletonFrames.listen(
            (frame) {
          latestFrame = frame;
          notifyListeners();
        },
        onError: (e) {
          streamState = ErrorState(e.toString());
          notifyListeners();
        },
      );
    } catch (e) {
      streamState = ErrorState(e.toString());
      notifyListeners();
    }
  }

  // ── Stop stream ────────────────────────────────────────────────────────────

  Future<void> stopStream() async {
    await _subscription?.cancel();
    _subscription  = null;
    await _repo.stop();
    streamState    = const IdleState();
    latestFrame    = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}