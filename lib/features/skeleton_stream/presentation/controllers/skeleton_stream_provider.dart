// ─────────────────────────────────────────────────────────────────────────────
// features/skeleton_stream/presentation/controllers/skeleton_stream_provider.dart
//
// FIX: dispose() calls stopStream() so the manager is always cleaned up when
// the ChangeNotifierProvider leaves the widget tree (e.g. Navigator.pop).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:typed_data';

import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:altum_view_sdk/features/skeleton_stream/domain/repository/skeleton_stream_repository.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/managers/skeleton_stream_manager.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/skeleton_model.dart';

class SkeletonStreamProvider extends ChangeNotifier {
  final SkeletonStreamRepository _repo;
  SkeletonStreamProvider(this._repo);

  ViewState<void>  streamState  = const IdleState();
  SkeletonFrame?   latestFrame;
  Uint8List?       backgroundImage;
  StreamStatus     streamStatus = StreamStatus.idle;

  StreamSubscription<SkeletonFrame>? _frameSub;
  StreamSubscription<StreamStatus>?  _statusSub;

  bool _disposed = false;

  bool get isStreaming =>
      streamState is LoadingState || streamState is SuccessState;

  // ── Start ──────────────────────────────────────────────────────────────────

  Future<void> startStream() async {
    if (isStreaming || _disposed) return;

    streamState = const LoadingState();
    _notify();

    try {
      _statusSub = _repo.statusStream.listen((s) {
        streamStatus = s;
        _notify();
      });

      await _repo.start();

      backgroundImage = _repo.backgroundImage;
      streamState     = const SuccessState(null);
      _notify();

      _frameSub = _repo.skeletonFrames.listen(
            (frame) {
          latestFrame = frame;
          _notify();
        },
        onError: (e) {
          streamState = ErrorState(e.toString());
          _notify();
        },
      );
    } catch (e) {
      streamState = ErrorState(e.toString());
      _notify();
    }
  }

  // ── Stop ───────────────────────────────────────────────────────────────────

  Future<void> stopStream() async {
    await _frameSub?.cancel();
    await _statusSub?.cancel();
    _frameSub    = null;
    _statusSub   = null;
    await _repo.stop();
    streamState  = const IdleState();
    streamStatus = StreamStatus.idle;
    latestFrame  = null;
    _notify();
  }

  // ── Dispose — triggered automatically when provider leaves the tree ────────
  // This fires when Navigator.pop() removes SkeletonStreamScreen.

  @override
  void dispose() {
    _disposed = true;
    _frameSub?.cancel();
    _statusSub?.cancel();
    _repo.stop(); // stops MQTT, cancels timers, closes streams → no more logs
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}