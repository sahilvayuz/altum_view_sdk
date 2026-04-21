// ─────────────────────────────────────────────────────────────────────────────
// features/skeleton_stream/data/repositories/skeleton_stream_repository_impl.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:altum_view_sdk/features/skeleton_stream/domain/repository/skeleton_stream_repository.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/managers/skeleton_stream_manager.dart';
import '../../domain/models/skeleton_model.dart';

class SkeletonStreamRepositoryImpl implements SkeletonStreamRepository {
  final SkeletonStreamManager _manager;
  SkeletonStreamRepositoryImpl(this._manager);

  @override
  Future<void> start() => _manager.start();

  @override
  Future<void> stop() => _manager.stop();

  @override
  Stream<SkeletonFrame> get skeletonFrames => _manager.skeletonFrames;

  @override
  Stream<SkeletonStreamStatus> get statusStream => _manager.statusStream;

  @override
  Uint8List? get backgroundImage => _manager.backgroundImage;

  @override
  bool get cameraOffline => _manager.cameraOffline;
}