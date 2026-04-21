// ─────────────────────────────────────────────────────────────────────────────
// features/rooms/domain/repositories/room_repository.dart
// ─────────────────────────────────────────────────────────────────────────────


import 'package:altum_view_sdk/features/rooms/domain/models/room_model.dart';

abstract interface class RoomRepository {
  Future<List<RoomModel>> getRooms();
  Future<RoomModel>       createRoom(String name);
  Future<void>            updateRoom(int id, String name);
  Future<void>            deleteRoom(int id);
}