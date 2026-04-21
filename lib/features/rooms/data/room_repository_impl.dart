// ─────────────────────────────────────────────────────────────────────────────
// features/rooms/data/repositories/room_repository_impl.dart
//
// Implements the domain contract. Wraps remote calls in try/catch and converts
// raw DioExceptions into typed AppExceptions.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/networking/app_exception.dart';
import 'package:altum_view_sdk/features/rooms/data/room_remote_data_source.dart';
import 'package:altum_view_sdk/features/rooms/domain/models/room_model.dart';
import 'package:altum_view_sdk/features/rooms/domain/repositories/room_repository.dart';
import 'package:dio/dio.dart';


class RoomRepositoryImpl implements RoomRepository {
  final RoomRemoteDataSource _remote;
  RoomRepositoryImpl(this._remote);

  @override
  Future<List<RoomModel>> getRooms() => _safe(() => _remote.getRooms());

  @override
  Future<RoomModel> createRoom(String name) =>
      _safe(() => _remote.createRoom(name));

  @override
  Future<void> updateRoom(int id, String name) =>
      _safe(() => _remote.updateRoom(id, name));

  @override
  Future<void> deleteRoom(int id) => _safe(() => _remote.deleteRoom(id));

  // ── Error wrapper ─────────────────────────────────────────────────────────
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