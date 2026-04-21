// ─────────────────────────────────────────────────────────────────────────────
// features/rooms/data/sources/room_remote_data_source.dart
//
// All raw HTTP calls related to Rooms.
// Returns decoded model objects — no business logic here.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:altum_view_sdk/features/rooms/domain/models/room_model.dart';

abstract interface class RoomRemoteDataSource {
  Future<List<RoomModel>> getRooms();
  Future<RoomModel>       createRoom(String name);
  Future<void>            updateRoom(int id, String name);
  Future<void>            deleteRoom(int id);
}

class RoomRemoteDataSourceImpl implements RoomRemoteDataSource {
  final DioClient _client;
  RoomRemoteDataSourceImpl(this._client);

  @override
  Future<List<RoomModel>> getRooms() async {
    final resp = await _client.get(ApiConstants.rooms);
    final arr  = resp.data['data']?['rooms']?['array'] as List? ?? [];
    return arr.cast<Map<String, dynamic>>().map(RoomModel.fromJson).toList();
  }

  @override
  Future<RoomModel> createRoom(String name) async {
    final resp = await _client.post(
      ApiConstants.rooms,
      data: {'name': name},
    );
    final json = resp.data['data']?['room'] as Map<String, dynamic>;
    return RoomModel.fromJson(json);
  }

  @override
  Future<void> updateRoom(int id, String name) =>
      _client.patch(ApiConstants.roomById(id), data: {'name': name});

  @override
  Future<void> deleteRoom(int id) =>
      _client.delete(ApiConstants.roomById(id));
}