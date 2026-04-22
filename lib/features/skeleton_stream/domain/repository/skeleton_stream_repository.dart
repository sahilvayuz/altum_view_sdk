// ─────────────────────────────────────────────────────────────────────────────
// features/skeleton_stream/domain/repository/skeleton_stream_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import '../models/skeleton_model.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/managers/skeleton_stream_manager.dart';

abstract interface class SkeletonStreamRepository {
  Future<void>          start();
  Future<void>          stop();
  Stream<SkeletonFrame> get skeletonFrames;
  Stream<StreamStatus>  get statusStream;
  Uint8List?            get backgroundImage;
  StreamStatus          get status;
}