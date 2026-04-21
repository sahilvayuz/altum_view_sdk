// ─────────────────────────────────────────────────────────────────────────────
// features/skeleton_stream/domain/repository/skeleton_stream_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import '../models/skeleton_model.dart';

abstract interface class SkeletonStreamRepository {
  Future<void> start();
  Future<void> stop();
  Stream<SkeletonFrame> get skeletonFrames;
  Stream<SkeletonStreamStatus> get statusStream;
  Uint8List? get backgroundImage;
  bool get cameraOffline;
}