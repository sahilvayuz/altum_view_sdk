// ─────────────────────────────────────────────────────────────────────────────
// features/rooms/data/models/room_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class RoomModel {
  final int    id;
  final String name;
  final int?   cameraCount;

  const RoomModel({
    required this.id,
    required this.name,
    this.cameraCount,
  });

  factory RoomModel.fromJson(Map<String, dynamic> j) => RoomModel(
    id:          (j['id']           as num).toInt(),
    name:         j['name']         as String? ?? 'Unnamed Room',
    cameraCount: (j['camera_count'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id':   id,
    'name': name,
  };
}